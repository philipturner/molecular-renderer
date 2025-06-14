// Next steps:
// - Revise how the window and swap chain are initialized, ensuring the window
//   always appears on the monitor with the highest refresh rate.
//   - Reference article: Microsoft documentation, "Positioning Objects on
//     Multiple Display Monitors"
//   - We need to inspect more functions to find the fastest monitor in a
//     multi-display system. This might be independent of the ID3D12Device,
//     removing the dependency of 'Display' on 'Device'.
// - Merge all of the utility code between macOS and Windows.

import MolecularRenderer

#if os(macOS)
import Metal

@MainActor
func createApplication() -> Application {
  // Set up the device.
  var deviceDesc = DeviceDescriptor()
  deviceDesc.deviceID = Device.fastestDeviceID
  let device = Device(descriptor: deviceDesc)
  
  // Set up the display.
  var displayDesc = DisplayDescriptor()
  displayDesc.renderTargetSize = 1920
  displayDesc.screenID = Display.fastestScreenID
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.device = device
  applicationDesc.display = display
  let application = Application(descriptor: applicationDesc)
  
  return application
}

func createShaderSource() -> String {
  """
  
  #include <metal_stdlib>
  using namespace metal;
  
  struct TimeArguments {
    float time0;
    float time1;
    float time2;
  };
  
  float convertToChannel(
    float hue,
    float saturation,
    float lightness,
    uint n
  ) {
    float k = float(n) + hue / 30;
    k -= 12 * floor(k / 12);
    
    float a = saturation;
    a *= min(lightness, 1 - lightness);
    
    float output = min(k - 3, 9 - k);
    output = max(output, float(-1));
    output = min(output, float(1));
    output = lightness - a * output;
    return output;
  }
  
  kernel void renderImage(
    constant TimeArguments &timeArgs [[buffer(0)]],
    texture2d<float, access::write> frameBuffer [[texture(1)]],
    uint2 tid [[thread_position_in_grid]]
  ) {
    // Query the screen's dimensions.
    uint screenWidth = frameBuffer.get_width();
    uint screenHeight = frameBuffer.get_height();
    
    // Specify the arrangement of the bars.
    float line0 = float(screenHeight) * float(15) / 18;
    float line1 = float(screenHeight) * float(16) / 18;
    float line2 = float(screenHeight) * float(17) / 18;
    
    // Render something based on the pixel's position.
    float4 color;
    if (float(tid.y) < line0) {
      color = float4(0.707, 0.707, 0.00, 1.00);
    } else {
      float progress = float(tid.x) / float(screenWidth);
      if (float(tid.y) < line1) {
        progress += timeArgs.time0;
      } else if (float(tid.y) < line2) {
        progress += timeArgs.time1;
      } else {
        progress += timeArgs.time2;
      }
      
      float hue = float(progress) * 360;
      float saturation = 1.0;
      float lightness = 0.5;
      
      float red = convertToChannel(hue, saturation, lightness, 0);
      float green = convertToChannel(hue, saturation, lightness, 8);
      float blue = convertToChannel(hue, saturation, lightness, 4);
      color = float4(red, green, blue, 1.00);
    }
    
    // Write the pixel to the screen.
    frameBuffer.write(color, tid);
  }
  
  """
}

// Set up the application.
let application = createApplication()

// Set up the shader.
var shaderDesc = ShaderDescriptor()
shaderDesc.device = application.device
shaderDesc.name = "renderImage"
shaderDesc.source = createShaderSource()
shaderDesc.threadsPerGroup = SIMD3(8, 8, 1)
let shader = Shader(descriptor: shaderDesc)

// Define the state variables.
var startTime: UInt64?

// Enter the run loop.
application.run { renderTarget in
  application.device.commandQueue.withCommandList { commandList in
    // Utility function for calculating progress values.
    var times: SIMD3<Float> = .zero
    func setTime(_ time: Double, index: Int) {
      let fractionalTime = time - floor(time)
      times[index] = Float(fractionalTime)
    }
    
    // Write the absolute time.
    if let startTime {
      let currentTime = mach_continuous_time()
      let timeSeconds = Double(currentTime - startTime) / 24_000_000
      setTime(timeSeconds, index: 0)
    } else {
      startTime = mach_continuous_time()
      setTime(Double.zero, index: 0)
    }
    
    // Write the time according to the counter.
    do {
      let clock = application.clock
      let timeInFrames = clock.frames
      let framesPerSecond = application.display.frameRate
      let timeInSeconds = Double(timeInFrames) / Double(framesPerSecond)
      setTime(timeInSeconds, index: 1)
      setTime(Double.zero, index: 2)
    }
    
    // Fill the arguments data structure.
    struct TimeArguments {
      var time0: Float = .zero
      var time1: Float = .zero
      var time2: Float = .zero
    }
    var timeArgs = TimeArguments()
    timeArgs.time0 = times[0]
    timeArgs.time1 = times[1]
    timeArgs.time2 = times[2]
    
    // Encode the compute command.
    commandList.withPipelineState(shader) {
      commandList.set32BitConstants(timeArgs, index: 0)
      commandList.mtlCommandEncoder
        .setTexture(renderTarget, index: 1)
      
      let groups = SIMD3<UInt32>(
        UInt32(renderTarget.width) / 8,
        UInt32(renderTarget.height) / 8,
        1)
      commandList.dispatch(groups: groups)
    }
  }
}

#endif



#if os(Windows)
import SwiftCOM
import WinSDK

#if false
let window = Application.global.window
ShowWindow(window, SW_SHOW)

// Invoke the game loop.
SetPriorityClass(GetCurrentProcess(), UInt32(HIGH_PRIORITY_CLASS))
while true {
  var message = MSG()
  let peekMessageOutput = PeekMessageA(
    &message, // lpMsg
    nil, // hWnd
    0, // wMsgFilterMin
    0, // wMsgFilterMax
    UInt32(PM_REMOVE)) // wRemoveMsg
  
  if message.message == WM_QUIT {
    break
  } else if peekMessageOutput {
    TranslateMessage(&message)
    DispatchMessageA(&message)
  }
}
#endif



SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)

var displayDevice = DISPLAY_DEVICE()
displayDevice.cb = UInt32(MemoryLayout<DISPLAY_DEVICE>.size)

// 0, 1, 2, 3 - NVIDIA GeForce GTX 970
// 4, 5, 6 - Intel(R) HD Graphics 4600
// Only device 0 has non-zero flags.

// \\.\DISPLAY1
//
// \\.\DISPLAY1\Monitor0
// Generic PnP Monitor

let lpDevice = "\\\\.\\DISPLAY1"
let output = EnumDisplayDevicesA(
  lpDevice,
  0,
  &displayDevice,
  0) // UInt32(EDD_GET_DEVICE_INTERFACE_NAME))
print("Result of EnumDisplayDevices:", output)

print()
withUnsafePointer(to: displayDevice.DeviceName) { pointer in
  let opaque = UnsafeRawPointer(pointer)
  let casted = opaque.assumingMemoryBound(to: Int8.self)
  print(String(cString: casted))
}

print()
withUnsafePointer(to: displayDevice.DeviceString) { pointer in
  let opaque = UnsafeRawPointer(pointer)
  let casted = opaque.assumingMemoryBound(to: Int8.self)
  print(String(cString: casted))
}

print()
print(displayDevice.StateFlags)
print("---")
print(DISPLAY_DEVICE_ACTIVE)
print(DISPLAY_DEVICE_MIRRORING_DRIVER)
print(DISPLAY_DEVICE_MODESPRUNED)
print(DISPLAY_DEVICE_PRIMARY_DEVICE)
print(DISPLAY_DEVICE_REMOVABLE)
print(DISPLAY_DEVICE_VGA_COMPATIBLE)
print(DISPLAY_DEVICE_ATTACHED)
print(DISPLAY_DEVICE_ATTACHED_TO_DESKTOP)

print()
withUnsafePointer(to: displayDevice.DeviceID) { pointer in
  let opaque = UnsafeRawPointer(pointer)
  let casted = opaque.assumingMemoryBound(to: Int8.self)
  print(String(cString: casted))
}

print()
withUnsafePointer(to: displayDevice.DeviceKey) { pointer in
  let opaque = UnsafeRawPointer(pointer)
  let casted = opaque.assumingMemoryBound(to: Int8.self)
  print(String(cString: casted))
}

#endif

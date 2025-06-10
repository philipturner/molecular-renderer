// Next steps:
// - Overhaul CommandList and CommandQueue.
//   - On Windows, establish a FIFO queue that's garbage collected from start
//     to end, every time a new command list is created. In addition, there's
//     a limit (~128) to the number of in-flight command lists before the
//     class crashes. Note that this is a temporary safeguard, to catch memory
//     leaks and similar bugs in the utility code.
//   - Get the new code working on Windows.
//   - Get the new code working on Mac.
// - Reproduce the 1st 3DGEP tutorial using empty render passes.
// - Reproduce the StackOverflow comment (https://stackoverflow.com/a/78501260)
//   about rendering with entirely compute commands.

import MolecularRenderer

#if os(macOS)
import Metal

@MainActor
func createApplication() -> Application {
  // Set up the display.
  var displayDesc = DisplayDescriptor()
  displayDesc.renderTargetSize = 1920
  displayDesc.screenID = Display.fastestScreenID
  let display = Display(descriptor: displayDesc)
  
  // Set up the device.
  var deviceDesc = DeviceDescriptor()
  deviceDesc.deviceID = Device.fastestDeviceID
  let device = Device(descriptor: deviceDesc)
  
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
  
  half convertToChannel(
    half hue,
    half saturation,
    half lightness,
    ushort n
  ) {
    half k = half(n) + hue / 30;
    k -= 12 * floor(k / 12);
  
    half a = saturation;
    a *= min(lightness, 1 - lightness);
  
    half output = min(k - 3, 9 - k);
    output = max(output, half(-1));
    output = min(output, half(1));
    output = lightness - a * output;
    return output;
  }
  
  kernel void renderImage(
    constant float *time0 [[buffer(0)]],
    constant float *time1 [[buffer(1)]],
    constant float *time2 [[buffer(2)]],
    texture2d<half, access::write> drawableTexture [[texture(0)]],
    ushort2 tid [[thread_position_in_grid]]
  ) {
    half4 color;
    if (tid.y < 1600) {
      color = half4(0.707, 0.707, 0.00, 1.00);
    } else {
      float progress = float(tid.x) / 1920;
      if (tid.y < 1600 + 107) {
        progress += *time0;
      } else if (tid.y < 1600 + 213) {
        progress += *time1;
      } else {
        progress += *time2;
      }
  
      half hue = half(progress) * 360;
      half saturation = 1.0;
      half lightness = 0.5;
  
      half red = convertToChannel(hue, saturation, lightness, 0);
      half green = convertToChannel(hue, saturation, lightness, 8);
      half blue = convertToChannel(hue, saturation, lightness, 4);
      color = half4(red, green, blue, 1.00);
    }
  
    drawableTexture.write(color, tid);
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
  // Start the command list.
  let commandList = application.device.createCommandList()
  
  // Utility function for encoding constants.
  func setTime(_ time: Double, index: Int) {
    let fractionalTime = time - floor(time)
    var time32 = Float(fractionalTime)
    commandList.mtlCommandEncoder
      .setBytes(&time32, length: 4, index: index)
  }
  
  // Bind buffer 0.
  if let startTime {
    let currentTime = mach_continuous_time()
    let timeSeconds = Double(currentTime - startTime) / 24_000_000
    setTime(timeSeconds, index: 0)
  } else {
    startTime = mach_continuous_time()
    setTime(Double.zero, index: 0)
  }
  
  // Bind buffers 1 and 2.
  do {
    let clock = application.clock
    let timeInFrames = clock.frames
    let framesPerSecond = application.display.frameRate
    let timeInSeconds = Double(timeInFrames) / Double(framesPerSecond)
    setTime(timeInSeconds, index: 1)
    setTime(Double.zero, index: 2)
  }
  
  // Bind the textures.
  commandList.mtlCommandEncoder
    .setTexture(renderTarget, index: 0)
  
  // Bind the pipeline state.
  commandList.setPipelineState(shader)
  
  // Encode the dispatch.
  let groups = SIMD3<UInt32>(
    UInt32(renderTarget.width) / 8,
    UInt32(renderTarget.height) / 8,
    1)
  commandList.dispatch(groups: groups)
  
  // End the command list.
  application.device.commit(commandList)
}

#endif



#if os(Windows)
import SwiftCOM
import WinSDK

/*
let window = Application.global.window
ShowWindow(window, SW_SHOW)

// Invoke the game loop.
while true {
  var message = MSG()
  PeekMessageA(
    &message, // lpMsg
    nil, // hWnd
    0, // wMsgFilterMin
    0, // wMsgFilterMax
    UInt32(PM_REMOVE)) // wRemoveMsg
  
  if message.message == WM_QUIT {
    break
  } else {
    TranslateMessage(&message)
    DispatchMessageA(&message)
  }
}
*/

let device = Application.global.device

// TODO: Verify that this test procedure works on Mac.
for frameID in 0..<100 {
  print("frame ID:", frameID)
  
  device.commandQueue.withCommandList { commandList in
    _ = commandList
  }
}

device.commandQueue.flush()
print("Finished the program.")

#endif

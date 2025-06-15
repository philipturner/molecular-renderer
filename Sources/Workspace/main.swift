// Next steps:
// - Revise how the window and swap chain are initialized, ensuring the window
//   always appears on the monitor with the highest refresh rate.
//   - Reference article: Microsoft documentation, "Positioning Objects on
//     Multiple Display Monitors"
//     - Reading the sub-articles of "About Multiple Display Monitors".
//     - Next one to read: "Using Multiple Monitors as Independent Displays".
//   - We need to inspect more functions to find the fastest monitor in a
//     multi-display system. This might be independent of the ID3D12Device,
//     removing the dependency of 'Display' on 'Device'.
// - Mark a commit in the Git history as "important", instead of archiving in
//   another tedious GitHub gist.
// - Merge all of the utility code between macOS and Windows.
//   - This will be severely API-breaking, and the source tree won't compile
//     correctly for most of the process.
//   - Exception: too early to merge 'Upscaler' from Windows.

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

// EnumDisplayDevices
//
// 0, 1, 2, 3 - NVIDIA GeForce GTX 970
// 4, 5, 6 - Intel(R) HD Graphics 4600
// Only device 0 has non-zero flags.

// EnumDisplayDevices
//
// \\.\DISPLAY1
//
// \\.\DISPLAY1\Monitor0
// Generic PnP Monitor

// EnumDisplaySettings
//
// This function supposedly does not participate in DPI virtualization.
//
// lpszDeviceName = "\\.\DISPLAY1"
// iModeNum = UInt32.max
//
// devMode.dmBitsPerPel = 32
// devMode.dmPelsWidth = 3840
// devMode.dmPelsHeight = 2160
// devMode.dmDisplayFlags = 0
// devMode.dmDisplayFrequency = 60

// EnumDisplayMonitors
//
// Only enumerates over a single monitor. Fetches a valid HMONITOR pointer.
// The LPRECT changes from 2560x1440 to 3840x2160 based on the DPI awareness
// context.

// GetMonitorInfo
//
// Returns "\\.\DISPLAY1" for the device name.
//
// DPI awareness off:
// rcMonitor = (0, 0, 2560, 1440)
// rcWork = (0, 0, 2560, 1400)
//
// DPI awareness on:
// rcMonitor = (0, 0, 3840, 2160)
// rcWork = (0, 0, 3840, 2100)

// # Conclusion
//
// IDXGIAdapter -> IDXGIOutput -> GetDesc -> HMONITOR
// A system have multiple adapters, each of which maps to a 'Device'. A
// device has multiple outputs, each of which maps to a 'Display'. Modify the
// existing utilities so that '.fastestScreenID' belongs to an instance of
// 'Device', not the 'Display' type object. This creates an inevitable
// inconsistency between the appearance of the two APIs for "fastest" IDs.
//
// For window dimensions, use HMONITOR -> GetMonitorInfo -> rcWork
// Use rcWork for consistency with macOS, which centers the window in the
// "work area" of the screen.
//
// For device name, there are two paths:
// GetDesc -> DeviceName -> convert WCHAR to CHAR
// HMONITOR -> GetMonitorInfo -> MONITORINFOEXA -> szDevice
// The first seems easiest.
//
// For refresh rate, there are two paths:
// IDXGIOutput -> GetDisplayModeList -> filter based on resolution -> RefreshRate
// device name -> EnumDisplaySettings -> iModeNum = UInt32.max -> dmDisplayFrequency
// The latter seems more appropriate because it reflects the system's current
// refresh rate.

func monitorInfoProcedure(
  _ unnamedParam1: HMONITOR?,
  _ unnamedParam2: HDC?,
  _ unnamedParam3: LPRECT?,
  _ unnamedParam4: LPARAM
) -> WindowsBool {
  guard let hMonitor = unnamedParam1 else {
    return false
  }
  
  withUnsafeTemporaryAllocation(
    byteCount: MemoryLayout<MONITORINFOEX>.size,
    alignment: MemoryLayout<MONITORINFOEX>.alignment
  ) { pRaw in
    let pMonitorInfo = pRaw.assumingMemoryBound(to: MONITORINFO.self)
    pMonitorInfo[0].cbSize = UInt32(MemoryLayout<MONITORINFOEX>.size)
    
    let output = GetMonitorInfoA(hMonitor, pMonitorInfo.baseAddress)
    print("output of GetMonitorInfoA:", output)
    
    let pMonitorInfoEx = pRaw.assumingMemoryBound(to: MONITORINFOEX.self)
    print(pMonitorInfoEx[0].cbSize)
    print(pMonitorInfoEx[0].rcMonitor)
    print(pMonitorInfoEx[0].rcWork)
    print(pMonitorInfoEx[0].dwFlags)
    print(pMonitorInfoEx[0].szDevice)
    
    let deviceName = pMonitorInfoEx[0].szDevice
    withUnsafePointer(to: deviceName) { pointer in
      let opaque = UnsafeRawPointer(pointer)
      let casted = opaque.assumingMemoryBound(to: Int8.self)
      print(String(cString: casted))
    }
  }
  
  return true
}

EnumDisplayMonitors(nil, nil, monitorInfoProcedure, 0)
print("Safely exited EnumDisplayMonitors.")

#endif

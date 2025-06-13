// Next steps:
// - Get frame ID synchronization correct on Windows.
//   - See whether Microsoft lets you query the next "video" timestamp,
//     compared to the "host" timestamp, like with Apple CoreVideo. [DONE]
//   - Inspect all of the following APIs:
//     - IDXGISwapChain::GetContainingOutput [DONE]
//     - IDXGIAdapter::EnumOutputs [DONE]
//     - IDXGIOutput::GetDisplayModeList [DONE]
//       - Find the highest display resolution available.
//       - Reject all modes with lower resolution.
//       - Find the highest refresh rate available.
//     - IDXGISwapChain::GetFrameStatistics
//       - DXGI_FRAME_STATISTICS.PresentCount
//       - DXGI_FRAME_STATISTICS.PresentRefreshCount
//       - DXGI_FRAME_STATISTICS.SyncRefreshCount
//       - DXGI_FRAME_STATISTICS.SyncQPCTime

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

let application = Application.global

// Reference code for selecting the fastest display.

/*
func createAdapters() -> [SwiftCOM.IDXGIAdapter4] {
  // Create the factory.
  let factory: SwiftCOM.IDXGIFactory4 =
  try! CreateDXGIFactory2(UInt32(DXGI_CREATE_FACTORY_DEBUG))
  
  // Create the adapters.
  var adapters: [SwiftCOM.IDXGIAdapter4] = []
  while true {
    // Check whether the next adapter exists.
    let adapterID = UInt32(adapters.count)
    let adapter = try? factory.EnumAdapters(adapterID)
    guard let adapter else {
      break
    }
    
    // Assume every adapter conforms to IDXGIAdapter4.
    let adapter4: SwiftCOM.IDXGIAdapter4 =
    try! adapter.QueryInterface()
    adapters.append(adapter4)
  }
  
  return adapters
}

let adapters = createAdapters()
for adapter in adapters {
  let desc = try! adapter.GetDesc()
  
  var descriptionCString: [CChar] = []
  withUnsafePointer(to: desc) { pRaw in
    let pDescription = UnsafeRawPointer(pRaw)
      .assumingMemoryBound(to: UInt16.self)
    for laneID in 0..<128 {
      let wideCharacter = pDescription[laneID]
      let character = CChar(wideCharacter)
      if character != 0 {
        descriptionCString.append(character)
      }
    }
  }
  descriptionCString.append(0)
  
  let descriptionString = String(cString: descriptionCString)
  print()
  print(descriptionString, terminator: ", ")
  
  let memorySizes: [UInt64] = [
    desc.DedicatedVideoMemory,
    desc.DedicatedSystemMemory,
    desc.SharedSystemMemory
  ]
  for memorySize in memorySizes {
    let memorySizeInMB = memorySize / 1024 / 1024
    let memorySizeInGB = Float16(Float(memorySizeInMB) / Float(1024))
    print("\(memorySize) B", terminator: ", ")
  }
  print()
  
  var outputs: [SwiftCOM.IDXGIOutput] = []
  var outputID: UInt32 = .zero
  while true {
    let output = try? adapter.EnumOutputs(outputID)
    if let output {
      outputs.append(output)
      outputID += 1
    } else {
      break
    }
  }
  print(outputs.count)
  
  for output in outputs {
    print("display mode")
    var displayModes = try! output.GetDisplayModeList(
      DXGI_FORMAT_R10G10B10A2_UNORM, 0)
    guard displayModes.count > 0 else {
      fatalError("Count not find display modes.")
    }
    print(displayModes.count)
    
    // Find the highest display resolution available.
    var highestResolution: SIMD2<UInt32> = .zero
    for displayMode in displayModes {
      let candidateResolution = SIMD2(
        UInt32(displayMode.Width),
        UInt32(displayMode.Height)
      )
      
      let highestPixels = highestResolution[0] * highestResolution[1]
      let candidatePixels = candidateResolution[0] * candidateResolution[1]
      if candidatePixels > highestPixels {
        highestResolution = candidateResolution
      }
    }
    let highestPixels = highestResolution[0] * highestResolution[1]
    guard highestPixels > 0 else {
      fatalError("Could not find highest resolution.")
    }
    print(highestResolution)
    
    // Reject all modes with lower resolution.
    displayModes = displayModes.filter {
      $0.Width == highestResolution[0] &&
      $0.Height == highestResolution[1]
    }
    print(displayModes.count)
    
    // Find the highest refresh rate available.
    var highestRefreshRate: Int = .zero
    for displayMode in displayModes {
      let numerator = Double(displayMode.RefreshRate.Numerator)
      let denominator = Double(displayMode.RefreshRate.Denominator)
      
      var refreshRateFP64 = numerator / denominator
      refreshRateFP64.round(.toNearestOrEven)
      let refreshRateInt = Int(refreshRateFP64)
      
      if refreshRateInt > highestRefreshRate {
        highestRefreshRate = refreshRateInt
      }
    }
    guard highestRefreshRate > 0 else {
      fatalError("Could not find highest refresh rate.")
    }
    print(highestRefreshRate)
  }
}
*/

#endif

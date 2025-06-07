// Next steps:
// - Use the vector addition example to check that all 3 new APIs (Device,
//   CommandQueue, Shader) work correctly at runtime. Especially the
//   functionality that flushes a command queue.

import MolecularRenderer

#if os(macOS)
import Metal

#if false

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
    commandList.setBytes(&time32, length: 4, index: index)
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
  commandList.setTexture(renderTarget, index: 0)
  
  // Bind the pipeline state.
  commandList.setComputePipelineState(shader.mtlComputePipelineState)
  
  // Encode the dispatch.
  do {
    let width = Int(renderTarget.width)
    let height = Int(renderTarget.height)
    commandList.dispatchThreads(
      MTLSize(width: width, height: height, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
  }
  
  // End the command list.
  application.device.commit(commandList)
}

#endif

#endif



#if os(Windows)
import SwiftCOM
import WinSDK

// Before proceeding, let's get a high-level understanding of the various API
// objects and their relationships. How should one organize them? I can
// "complete" the 3DGEP tutorial by just using its code as reference.
//
// Abstract goals and time-consuming API development are not helpful at this
// point. Look for little, specific things and unanswered questions. Don't add
// code to the helper library until it's needed for the current task.
//
// Periodically purge the main file in small bits, instead of all at once to a
// GitHub gist. That removes the need for any more tedious archival events.

// Second question: Should I create a helper class called 'Texture'?
//
// Answer: No, because the reference implementation
// (https://stackoverflow.com/a/78501260) just extracts the resource
// descriptor from a swapchain buffer. It might be tractable to keep the
// texture initialization code separate between Metal and DirectX.

#if false
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

#endif

// Next steps: [DONE]
// - Rename 'GPUContext' to 'Device' and bring out of macOS. [DONE]
// - Merge the Windows code for 'Device' and 'CommandQueue'. [DONE]
//   - Bring 'CommandQueue' into the common files. [DONE]
//   - Get the code to compile on Windows. [DONE]
//   - Remove the title ('lpWindowName') from the window. [DONE]
//   - Change the window clas ('lpClassName') to "Window". [DONE]
// - Correct the areas of the Mac code that still call it 'gpuContext'. [DONE]
//   - Get the code to compile on Mac. [DONE]
//   - Address the TODOs regarding command buffers in RunLoop. [DONE]
//


#endif



// MARK: - Vector Addition
//
// Code for vector addition, written in a cross-platform style.

// TODO: Add MTLSize to the shader for threadgroup size.
// TODO: Port 'Buffer' to macOS, but restrict the enumeration to only have the
// type '.native'.

func createShaderSource() -> String {
  #if os(macOS)
  
  #else
  """
  
  RWStructuredBuffer<float> buffer0 : register(u0);
  RWStructuredBuffer<float> buffer1 : register(u1);
  RWStructuredBuffer<float> buffer2 : register(u2);
  
  #define mainRS "UAV(u0), " \\
                "UAV(u1), " \\
                "UAV(u2)"
  
  // Still no solution to the difference in how each API encodes the number
  // of threads. Perhaps it's better to specify differently on macOS vs Windows,
  // as they might have different GPU architectures. But we'll eventually
  // need a utility to abstract away the process of specifying shader dispatch
  // size.
  //
  // Shader function name is already being included in the descriptor. It's
  // redundant, and requires conscious checking from the user. By that logic,
  // it's completely sensible to specify the dispatch size.
  [numthreads(128, 1, 1)]
  [RootSignature(mainRS)]
  void main(
    uint3 tid : SV_DispatchThreadID
  ) {
    uint slotID = tid.x;
    float input0 = buffer0[slotID];
    float input1 = buffer1[slotID];
    
    float output = input1 / input0;
    buffer2[slotID] = output;
  }
  
  """
  #endif
}

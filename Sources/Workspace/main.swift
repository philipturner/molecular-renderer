// Next steps:
// - Access the GPU.
//   - Modify it to get Metal rendering. [DONE]
//   - Clean up and simplify the code as much as possible. [DONE]
//   - Get timestamps synchronizing properly (moving rainbow banner
//     scene). [DONE]
// - Repeat the same process with COM / D3D12 on Windows.
//   - Get some general experience with C++ DirectX sample code.
//   - Modify the files one-by-one to support Windows.

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
  
  // Set up the GPU context.
  var gpuContextDesc = GPUContextDescriptor()
  gpuContextDesc.deviceID = GPUContext.fastestDeviceID
  let gpuContext = GPUContext(descriptor: gpuContextDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.display = display
  applicationDesc.gpuContext = gpuContext
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

func createRenderPipeline(
  application: Application,
  shaderSource: String
) -> MTLComputePipelineState {
  let device = application.gpuContext.device
  let shaderSource = createShaderSource()
  let library = try! device.makeLibrary(source: shaderSource, options: nil)
  
  let function = library.makeFunction(name: "renderImage")
  guard let function else {
    fatalError("Could not make function.")
  }
  let pipeline = try! device.makeComputePipelineState(function: function)
  return pipeline
}

// Set up the resources.
let application = createApplication()
let shaderSource = createShaderSource()
let renderPipeline = createRenderPipeline(
  application: application,
  shaderSource: shaderSource)

var startTime: UInt64?
var frameID: Int = .zero

// Enter the run loop.
application.run { renderTarget in
  frameID += 1
  
  // Start the command encoder.
  let commandQueue = application.gpuContext.commandQueue
  let commandBuffer = commandQueue.makeCommandBuffer()!
  let encoder = commandBuffer.makeComputeCommandEncoder()!
  
  // Bind the buffers.
  do {
    func setTime(_ time: Double, index: Int) {
      let fractionalTime = time - floor(time)
      var time32 = Float(fractionalTime)
      encoder.setBytes(&time32, length: 4, index: index)
    }
    
    if let startTime {
      let currentTime = mach_continuous_time()
      let timeSeconds = Double(currentTime - startTime) / 24_000_000
      setTime(timeSeconds, index: 0)
    } else {
      startTime = mach_continuous_time()
      setTime(Double.zero, index: 0)
    }
    
    let clock = application.clock
    let timeInFrames = clock.frames
    let framesPerSecond = application.display.frameRate
    let timeInSeconds = Double(timeInFrames) / Double(framesPerSecond)
    setTime(timeInSeconds, index: 1)
    
    setTime(Double.zero, index: 2)
  }
  
  // Bind the textures.
  encoder.setTexture(renderTarget, index: 0)
  
  // Dispatch
  do {
    encoder.setComputePipelineState(renderPipeline)
    
    let width = Int(renderTarget.width)
    let height = Int(renderTarget.height)
    encoder.dispatchThreads(
      MTLSize(width: width, height: height, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
  }
  
  // End the command encoder.
  encoder.endEncoding()
  commandBuffer.commit()
}
#endif



#if os(Windows)
import SwiftCOM
import WinSDK

// Objectives:
// (1) Integrate the debug layer into device initialization. Set it to break
//     only on 'ERROR'.
// (2) Integrate state tracking into Buffer.
// (3) Create an instance member of Buffer called 'transition', which returns
//     a DirectX resource barrier value type.
// (4) Reproduce the previous code for copy commands, and verify that the debug
//     layer is working as expected.

let device = DirectXDevice()
print(device.d3d12Debug)
print(device.d3d12Device)
print(device.d3d12InfoQueue)

#if false

let vectorAddition = VectorAddition(device: device)
let commandQueue = CommandQueue(device: device)
let commandList = commandQueue.createCommandList()

// Copy command: inputBuffer0 -> nativeBuffer0
do {
  let barrier = vectorAddition.nativeBuffer0
    .transition(state: D3D12_RESOURCE_STATE_COPY_DEST)
  let barriers = [barrier]
  
  try! commandList.ResourceBarrier(
    UInt32(barriers.count), barriers)
  try! commandList.CopyResource(
    vectorAddition.nativeBuffer0.d3d12Resource,
    vectorAddition.inputBuffer0.d3d12Resource)
}
print("Encoded command 1 successfully.")

// Copy command: inputBuffer1 -> nativeBuffer1
do {
  let barrier = vectorAddition.nativeBuffer1
    .transition(state: D3D12_RESOURCE_STATE_COPY_DEST)
  let barriers = [barrier]
  
  try! commandList.ResourceBarrier(
    UInt32(barriers.count), barriers)
  try! commandList.CopyResource(
    vectorAddition.nativeBuffer1.d3d12Resource,
    vectorAddition.inputBuffer1.d3d12Resource)
}
print("Encoded command 2 successfully.")

// Copy command: nativeBuffer0 -> nativeBuffer2
do {
  let barrier0 = vectorAddition.nativeBuffer0
    .transition(state: D3D12_RESOURCE_STATE_COPY_SOURCE)
  let barrier2 = vectorAddition.nativeBuffer2
    .transition(state: D3D12_RESOURCE_STATE_COPY_DEST)
  let barriers = [barrier0, barrier2]
  
  try! commandList.ResourceBarrier(
    UInt32(barriers.count), barriers)
  try! commandList.CopyResource(
    vectorAddition.nativeBuffer2.d3d12Resource,
    vectorAddition.nativeBuffer0.d3d12Resource)
}
print("Encoded command 3 successfully.")

// Copy command: nativeBuffer2 -> outputBuffer2
do {
  let barrier = vectorAddition.nativeBuffer2
    .transition(state: D3D12_RESOURCE_STATE_COPY_SOURCE)
  let barriers = [barrier]
  
  try! commandList.ResourceBarrier(
    UInt32(barriers.count), barriers)
  try! commandList.CopyResource(
    vectorAddition.outputBuffer2.d3d12Resource,
    vectorAddition.nativeBuffer2.d3d12Resource)
}
print("Encoded command 4 successfully.")

commandQueue.commit(commandList)
commandQueue.flush()
print("The commands completed on the GPU.")

// Check the data in the output buffer.
do {
  var outputData2: [Float] = []
  for i in 0..<1024 {
    outputData2.append(0)
  }
  
  outputData2.withUnsafeMutableBytes { bufferPointer in
    let baseAddress = bufferPointer.baseAddress!
    vectorAddition.outputBuffer2
      .read(output: baseAddress)
  }
  
  for slotID in 0..<10 {
    let value2 = outputData2[slotID]
    print("outputBuffer[\(slotID)] = \(value2)")
  }
}

#endif

// On to the next task. Before, remind myself:
// - What is the ultimate goal?
// - What is the next step after this one, toward the ultimate goal?

#endif

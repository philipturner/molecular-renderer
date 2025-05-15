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

// I want to achieve 'hello world' for vector addition.
//
// Issues:
// - How to create resources
// - How to create pipelines
// - What the heck is going on with descriptors
// - What the heck is going on with root signatures
// - How to bind resources to commands
// - How to dispatch GPU threads
// - What the heck is going on with resource state (transitions)
// - How to test the results of GPU execution
//
// The above notes are the start of a brainstorming session about how to
// approach this goal in practice. Next, I must elaborate on and refactor the
// ideas. I've started by purging this repository of the C++ translations.

// ## Initiation
//
// My goal is to execute a proof of concept compute-only workflow on the GPU.
// I will create three UAV buffers of type FP32. They will be read and written
// from GPU-native memory during a compute shader. The CPU will supply input
// data and test the output data.
//
// Additional requirements:
// - Correct/conventional usage of the DirectX 12 API
// - No memory leaks from mishandling COM objects
// - Shader is compiled entirely at runtime
// - Root signature is specified in HLSL, not on the CPU
// - Resources are bound in separate 'root descriptor' entries
// - Resources are not sub-resources of another resource
// - All objects for encoding commands are regenerated for each command list
//
// Resource states:
// - 'COPY_DEST' while moving from CPU -> GPU
// - 'UAV' while executing the compute shader
// - 'COPY_SRC' while moving from GPU -> CPU
// - There are no constant buffers or inlined 32-bit constants.
//
// Additional small details:
// - Compile the shader with the SM 6.5 target.
// - Dispatch 128 threads per group.
// - Each buffer is 1024 elements.
//   - First input is 0 to 1023, in ascending order.
//   - Second input is 1024 to 2047, in ascending order.
//   - Report the results for the first 10 entries explicitly.
//   - To cover the remaining entries, count the number that did/didn't match
//     results of an analytical formula.
// - In root signature v1.1, the UAV's flag is 'DATA_VOLATILE' by default.



// ## First Step
//
// Author the HLSL shader. Then, modify the DXCWrapper utility to provide the
// compiled blob.

let shaderSource: String = """
RWStructuredBuffer<float> buffer0 : register(u0);
RWStructuredBuffer<float> buffer1 : register(u1);
RWStructuredBuffer<float> buffer2 : register(u2);

#define mainRS "UAV(u0), " \\
               "UAV(u1), " \\
               "UAV(u2)"

[numthreads(128, 1, 1)]
[RootSignature(mainRS)]
void main(
  uint3 tid : SV_DispatchThreadID
) {
  uint slotID = tid.x;
  float input0 = buffer0[slotID];
  float input1 = buffer1[slotID];
  
  float output = input0 + input1;
  buffer2[slotID] = output;
}

"""

let device = DirectXDevice()
let compiler = Compiler(device: device)
let shaderBytecode = compiler.compile(source: shaderSource)



// ## Second Step
//
// See whether I can jump directly to creating a PSO and root signature object.

import SwiftCOM
import WinSDK

// Create the root signature.
var rootSignature: SwiftCOM.ID3D12RootSignature?
shaderBytecode.rootSignature.withUnsafeBytes { bufferPointer in
  let d3d12Device = device.d3d12Device
  rootSignature = try! d3d12Device.CreateRootSignature(
    0,
    bufferPointer.baseAddress,
    UInt64(bufferPointer.count))
}
guard let rootSignature else {
  fatalError("Could not create root signature.")
}

// Create the pipeline state.
var pipelineState: SwiftCOM.ID3D12PipelineState?
shaderBytecode.object.withUnsafeBytes { bufferPointer in
  var computeShader = D3D12_SHADER_BYTECODE()
  computeShader.pShaderBytecode = bufferPointer.baseAddress
  computeShader.BytecodeLength = UInt64(bufferPointer.count)
  
  var cachedPipelineState = D3D12_CACHED_PIPELINE_STATE()
  cachedPipelineState.pCachedBlob = nil
  cachedPipelineState.CachedBlobSizeInBytes = 0
  
  var computePipelineStateDesc = D3D12_COMPUTE_PIPELINE_STATE_DESC()
  try! rootSignature.perform(
    as: WinSDK.ID3D12RootSignature.self
  ) { pUnk in
    computePipelineStateDesc.pRootSignature = pUnk
  }
  computePipelineStateDesc.CS = computeShader
  computePipelineStateDesc.NodeMask = 0
  computePipelineStateDesc.CachedPSO = cachedPipelineState
  computePipelineStateDesc.Flags = D3D12_PIPELINE_STATE_FLAG_NONE
  
  let d3d12Device = device.d3d12Device
  var iid = SwiftCOM.ID3D12PipelineState.IID
  let pUnk = try! d3d12Device.CreateComputePipelineState(
    &computePipelineStateDesc, &iid)
  pipelineState = SwiftCOM.ID3D12PipelineState(
    pUnk: pUnk)
}
guard let pipelineState else {
  fatalError("Could not create pipeline state.")
}



// ## Third Step
//
// Create buffer objects and test the API for accessing mapped pointers.

// Fill the descriptor properties common to all buffers.
var bufferDesc = BufferDescriptor()
bufferDesc.device = device
bufferDesc.size = 1024 * 4

// Create the input buffers.
bufferDesc.type = .input
let inputBuffer0 = Buffer(descriptor: bufferDesc)
let inputBuffer1 = Buffer(descriptor: bufferDesc)

// Create the native buffers.
bufferDesc.type = .native
let nativeBuffer0 = Buffer(descriptor: bufferDesc)
let nativeBuffer1 = Buffer(descriptor: bufferDesc)
let nativeBuffer2 = Buffer(descriptor: bufferDesc)

// Create the output buffers.
bufferDesc.type = .output
let outputBuffer2 = Buffer(descriptor: bufferDesc)

// Generate the input data for the shader.
do {
  var inputData0: [Float] = []
  var inputData1: [Float] = []
  for i in 0..<1024 {
    let value0 = Float(i)
    let value1 = 1024 + Float(i)
    inputData0.append(value0)
    inputData1.append(value1)
  }
  
  inputData0.withUnsafeBytes { bufferPointer in
    let baseAddress = bufferPointer.baseAddress!
    inputBuffer0.write(input: baseAddress)
  }
  
  inputData1.withUnsafeBytes { bufferPointer in
    let baseAddress = bufferPointer.baseAddress!
    inputBuffer1.write(input: baseAddress)
  }
}

// Read the initial contents of the output buffer.
do {
  var outputData2: [Float] = []
  for i in 0..<1024 {
    let value2 = Float(i)
    outputData2.append(value2)
  }
  
  outputData2.withUnsafeMutableBytes { bufferPointer in
    let baseAddress = bufferPointer.baseAddress!
    outputBuffer2.read(output: baseAddress)
  }
  
  for slotID in 0..<10 {
    let value2 = outputData2[slotID]
    guard value2 == 0 else {
      fatalError("Output buffer was initialized to nonzero value.")
    }
  }
}

// Next steps:
// - Test the code for reading/writing mapped pointers. Set the input data to
//   an increasing list of floating point numbers. Study the results of reading
//   from the output buffer. It should at least overwrite the previous contents
//   of the CPU memory allocation.
// - Redefine the "3rd step" and "4th step". The third step is shortened to just
//   summarize what we've done above. The fourth step is to create a command
//   queue, command list, and set up the resources for copying.
// - "Hello world" will come from shifting the data through various buffers.
//   The output will match either buffer0 or buffer1 (of my choosing). The copy
//   commands must pass through a GPU private buffer(s) as an intermediate.
// - After that is done, proceed with the descriptors necessary to bind UAVs to
//   a compute command.



// ## Fourth Step
//
// Set up the command queue, command list, and anything else needed for copying
// buffers.

// List all the components needed to make this happen:
// - ID3D12CommandQueue
// - ID3D12CommandList
// - ID3D12CommandAllocator
// - ID3D12Fence
// - Windows OS event
//
// References to get started:
// - My worked examples of C++ translations
// - DirectX tutorials
// - Microsoft's online documentation
//
// Describe everything that will happen in the procedure, qualitatively, in
// chronological order. At the moment, we don't actually know the correct
// chronological order.
//
// - Create the command queue
// - Create the command allocator
// - Create the command list from the command allocator
// - Close the command allocator and command list
//
// - Bind the buffers
// - Encode the copy commands
// - Encode the fence signaling
// - Wait on the fence on the CPU
// - Read the contents of the output buffer
//
// - Copy commands:
//   - Copy inputBuffer0 to nativeBuffer0
//   - Copy inputBuffer1 to nativeBuffer1
//   - Copy either [nativeBuffer0, nativeBuffer1] to nativeBuffer2
//   - Copy nativeBuffer2 to outputBuffer2
//
// Regarding the command queue/list/fence, what object creates what?
// - ID3D12Device
//   - ID3D12CommandQueue
//   - ID3D12CommandAllocator
//     - ID3D12CommandList
//   - ID3D12Fence
// - CreateEventA
//   - HANDLE

// Let's start with a simple deliverable:
// - Create the above objects, without using utility classes.
// - Dispatch an empty command buffer.
// - Close or clean up the objects.

// Reference code. Will be cleaned up when the repo is purged to a new GitHub
// gist. In addition, all of the helpful comments on 'main.swift' will be
// preserved on the gist.
#if false

func createCommandQueue(
  device: SwiftCOM.ID3D12Device
) -> SwiftCOM.ID3D12CommandQueue {
  var commandQueueDesc = D3D12_COMMAND_QUEUE_DESC()
  commandQueueDesc.Type = D3D12_COMMAND_LIST_TYPE_COMPUTE
  commandQueueDesc.Priority = D3D12_COMMAND_QUEUE_PRIORITY_NORMAL.rawValue
  commandQueueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE
  commandQueueDesc.NodeMask = 0
  
  return try! device.CreateCommandQueue(commandQueueDesc)
}

func createCommandList(
  device: SwiftCOM.ID3D12Device
) -> SwiftCOM.ID3D12GraphicsCommandList {
  // Create the command allocator.
  let commandAllocator: SwiftCOM.ID3D12CommandAllocator =
  try! device.CreateCommandAllocator(
    D3D12_COMMAND_LIST_TYPE_COMPUTE)
  
  // Create the command list from the command allocator.
  let commandList: SwiftCOM.ID3D12GraphicsCommandList =
  try! device.CreateCommandList(
    0,
    D3D12_COMMAND_LIST_TYPE_COMPUTE,
    commandAllocator,
    nil)
  
  // The command list increments the command allocator's reference, as long as
  // the command list is alive.
  return commandList
}

func createFence(
  device: SwiftCOM.ID3D12Device
) -> SwiftCOM.ID3D12Fence {
  return try! device.CreateFence(
    0,
    D3D12_FENCE_FLAG_NONE)
}

func createEvent() -> UnsafeMutableRawPointer {
  let output = CreateEventA(nil, false, false, nil)
  guard let output else {
    fatalError("Failed to create event handle.")
  }
  return output
}

let commandQueue = createCommandQueue(
  device: device.d3d12Device)

let commandList = createCommandList(
  device: device.d3d12Device)

let fence = createFence(
  device: device.d3d12Device)

let event = createEvent()

print(commandQueue)
print(commandList)
print(fence)
print(event)

#endif

// `ID3D12CommandQueue.ExecuteCommandLists` is like `MTLCommandBuffer.commit` in
// Metal applications. It sends commands to the GPU.
//
// Fences are similar to `MTLCommandBuffer.waitUntilCompleted` and
// `DispatchSemaphore` in Metal applications. They wait until a specific command
// buffer has completed. In Metal, one of the functions can facilitate triple-
// buffering without retaining a reference to the command buffer.
//
// API for quickly freezing the queue until all commands have finished, and it
// is safe to read contents from the CPU:
// - Metal: commandBuffer.waitUntilCompleted()
// - DirectX: immediately create, signal, and wait on a fence
//
// API for triple buffering:
// - Metal: DispatchSemaphore and commandBuffer.setCompletedHandler()
// - DirectX: increment a fence counter after an entire frame, remember the
//            counter's value until a future frame that needs a resource
//
// Both APIs require an entire command list to be committed before waiting on
// a chunk of GPU work. It's not clear at what granularity you can gather
// execution latency data.
//
// MTLSharedEvent has similarities to ID3D12Fence. Especially the method
// `MTLSharedEvent.wait(untilSignaledValue:timeoutMS:)`. It is virtually
// identical to `WaitForSingleObject` on Windows.
//
// I don't know whether there's a Windows API for callbacks, similar to the Mac
// paradigm of using semaphores.
//
// I don't know whether using MTLSharedEvent causes performance issues on Mac.

// For the time being, we don't actually need to worry about triple-buffering
// of resources. The Mac side of the new codebase hasn't gotten that far yet.
// So just use fences as a means to immediately stall until a command buffer
// has completed.
//
// Option 1:
// - Every command buffer gets a unique ID, monotonically increasing from when
//   the command queue was first created.
// - You can wait for GPU work at the granularity of previous command buffers.
//   So, asynchronous compute.
//
// Option 2:
// - The command queue has an internal fence + event object created once at
//   initialization.
// - Every instance of CPU-side stalling blocks at the latest command dispatched
//   on that specific queue.
//
// Choose option 2.

// Another concern is the ability to profile GPU command execution time. In
// DirectX 12, ID3D12GraphicsCommandList.BeginQuery cannot be called on a
// timestamp query. Instead, call `EndQuery`.
//
// Source: https://pavelsmejkal.net/Posts/
//
// The DX12 'Query' paradigm for measuring time looks similar to the Metal
// 'MTLCounterSampleBuffer' paradigm. There is an additional step, where one
// must store timestamps in a special buffer. Not as easy as the Metal API for
// retrieving the '.gpuStartTime' and '.gpuEndTime' of a command buffer.
//
// In both APIs, you must be careful about the step size of timestamp counters.
// On Mac, it could be Mach absolute time (24 MHz) instead of nanoseconds.
// On Windows, you must call `ID3D12CommandQueue.GetTimestampFrequency.`
//
// One difference might be that Windows allows finer granularity of timestamp
// sampling. On Mac, `.gpuStartTime` and `.gpuEndTime` are scoped to the entire
// command buffer. The counter sample buffers API looks scoped to an entire
// compute command encoder, which has just as much latency as creating a new
// command buffer. Windows might allow finer granularity, because you can
// inject timestamps at any point within the command list. Including between
// subsequent compute commands, without a severe latency penalty.
//
// For the time being, neglect the ability to profile GPU-side execution time.



// ## Fourth Step (2nd Iteration)
//
// Create an ergonomic API for generating and waiting on empty GPU command
// buffers. Design the API with the intent to wrap a Metal backend in the
// future.
// - CommandQueue utility class
//   - 'flush' member function
//     - Windows: increment the fence counter, use a fence created when the
//                command queue initializes
//     - Mac: store a reference to the latest command buffer submitted to the
//            command queue
// - CommandBuffer utility class
//   - 'commit' member function
//     - Sends the command list to the command queue (perhaps this member
//       belongs in CommandQueue, and there is no utility class for
//       CommandBuffer).
//     - Closes the command list.
//   - No analogue to Metal 'waitUntilCompleted'
//
// To ease the prototyping process, just create an API for 'CommandQueue'. It
// creates and commits instances of 'ID3D12GraphicsCommandList'. The creation
// method abstracts away the 'ID3D12CommandAllocator'. The commit method
// abstracts away both 'commandList.Close()' and 'commandQueue.
// ExecuteCommandLists()'. The flush method works as described above.

#endif

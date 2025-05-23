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

let commandQueue = CommandQueue(device: device)
commandQueue.flush()
commandQueue.flush()

// Encapsulate the command buffer in a scope, so it can deinitialize itself.
//
// There is currently a problem with naming things both 'command buffer' and
// 'command list'. I have no solution at the moment.
do {
  let commandList = commandQueue.createCommandList()
  commandQueue.commit(commandList)
}
commandQueue.flush()



// ## Fifth Step
//
// Encode the copy commands into the command list.

let commandList = commandQueue.createCommandList()

// To start, copy inputBuffer0 to nativeBuffer0.
//
// Components of this task:
// - Identify methods of 'ID3D12(Graphics)CommandList' that bind the buffers
//   to the 'src' or 'dst' slots of a copy operation.
// - Identify the DirectX APIs for changing resource states.
// - Acknowledge the state of each buffer prior to the transition (or don't).
//
// Where to start: the 3DGEP tutorial series.
// - D3D12_RESOURCE_BARRIER
//   - D3D12_RESOURCE_BARRIER_TYPE
//     - Don't want to use '_TRANSITION', because we're not splitting individual
//       resources into subresources.
//     - Don't think '_UAV' applies to copy commands.
//   - D3D12_RESOURCE_FLAGS
//     - The '_BEGIN_ONLY' and '_END_ONLY' flags seem strange.
//   - union of the 3 possible types
//     - '_UAV_BARRIER' has the simplest data structure, just a pointer to the
//       resource.
//     - '_TRANSITION_BARRIER' also makes sense. I would use the 0xFFFFFFFF
//       flag because we don't have subresources (?).
// - D3D12_RESOURCE_STATES
// - Many members of 'ResourceStateTracker' just invoke the same method,
//   'ResourceBarrier'.
// - Microsoft documentation encourages batching multiple resource barriers
//   into a single call. If all of the 2 transitions are scoped to one utility
//   function for copying buffers, I can write the boilerplate code for this.
//   No need to design a general API for easing the creation of barrier objects.
//
// Call: d3d12CommandList.ResourceBarrier(numBarriers, resourceBarriers.data())
// - 'D3D12_RESOURCE_BARRIER' is a value type, not a COM reference type. This
//   fact makes barriers easier to aggregate and send through a C interface.
//
// Based on the 3DGEP tutorial series, we might have to know the resource's
// prior/current state to encode a barrier. This makes things more complicated;
// we must implement state tracking and carry it around everywhere.
//
// For the 'hello world' demonstration, we can ignore the state tracking. We
// know every resource's specific state ahead of time. It becomes an issue
// when we create an API that generalizes to arbitrary code. Something to
// possibly defer to after the 'hello world' demonstration.

// I may have figured out resource state transitions. Next, figure out the
// DirectX API function that encodes the copy command. And whether it requires
// additional calls to bind buffers to slots.

// ## Copy command(s) in the DirectX 12 API
//
// Object that calls the member functions: ID3D12GraphicsCommandList
//
// Member: CopyBufferRegion(ID3D12Resource *pDstBuffer,
//                          UINT64         DstOffset,
//                          ID3D12Resource *pSrcBuffer,
//                          UINT64         SrcOffset,
//                          UINT64         NumBytes)
//
// Member: CopyResource(ID3D12Resource *pDstResource,
//                      ID3D12Resource *pSrcResource)
//
// Member: CopyTextureRegion(const D3D12_TEXTURE_COPY_LOCATION *pDst,
//                           UINT                              DstX,
//                           UINT                              DstY,
//                           UINT                              DstZ,
//                           const D3D12_TEXTURE_COPY_LOCATION *pSrc,
//                           const D3D12_BOX                   *pSrcBox)
//
// Member: CopyTiles(const D3D12_TEXTURE_COPY_LOCATION *pDst,
//                   UINT                              DstX,
//                   UINT                              DstY,
//                   UINT                              DstZ,
//                   const D3D12_TEXTURE_COPY_LOCATION *pSrc,
//                   const D3D12_BOX                   *pSrcBox)

// I think I have figured out the copy command. Next, document the DirectX 12
// API functions associated with 'TransitionBarrier' and 'TrackResource'.

// ## ResourceStateTracker::FlushResourceBarriers
//
// Takes a 'CommandList' helper class as an argument. References a list of
// resource barrier objects. These objects are in fact value types, making the
// code easier to implement. Invokes the 'ResourceBarrier' method of
// 'ID3D12GraphicsCommandList' with the barrier count and barrier pointer.
// Deletes all entries in the barrier list.
//
// ## CommandList::TransitionBarrier
//
// Takes a reference to the 'ID3D12Resource'. Pretends the initial state is
// 'COMMON'. Sets the final state to the specified state. Appends the newly
// created 'D3D12_RESOURCE_BARRIER' value type to the list.
//
// ## CommandList::TrackResource
//
// Takes an 'ID3D12Resource' as an argument. Casts it to 'ID3D12Object' and
// appends it to an internal list.

// Finally, the whole source code snippet where 3DGEP performed a copy
// operation. This is a high-level guide for how to proceed with coding a copy
// operation in DirectX.
//
// void CommandList::CopyResource( Resource& dstRes, const Resource& srcRes )
// {
//     TransitionBarrier( dstRes, D3D12_RESOURCE_STATE_COPY_DEST );
//     TransitionBarrier( srcRes, D3D12_RESOURCE_STATE_COPY_SOURCE );
//
//     FlushResourceBarriers();
//
//     m_d3d12CommandList->CopyResource( dstRes.GetD3D12Resource().Get(), srcRes.GetD3D12Resource().Get() );
//
//     TrackResource(dstRes);
//     TrackResource(srcRes);
// }

// The task has now been specified in enough detail that I can do it.
//
// Or not. What's going on with COMMON?
// - Does the 3DGEP tutorial correct the pending commands, replacing the
//   'COMMON' placeholder with the true value?
// - If performance is not a concern, is it ideal to post-transition every
//   single resource back to 'COMMON' after every command?
//
// Ignore the common state. I think it skips calls to 'ResourceBarrier'
// entirely. Instead, start by specifying all the transitions that ought to
// occur throughout all 3 buffers.

// Initial states:
// inputBuffer0 - GENERIC_READ
// inputBuffer1 - GENERIC_READ
// nativeBuffer0 - COMMON
// nativeBuffer1 - COMMON
// nativeBuffer2 - COMMON
// outputBuffer2 - COPY_DEST
//
// Ideal states for a copy command:
// input - GENERIC_READ
// output - COPY_DEST
//
// Copy commands:
// - inputBuffer0 -> nativeBuffer0
//   - inputBuffer0: GENERIC_READ -> GENERIC_READ [omitted]
//   - nativeBuffer0: COMMON -> COPY_DEST
// - inputBuffer1 -> nativeBuffer1
//   - inputBuffer1: GENERIC_READ -> GENERIC_READ [omitted]
//   - nativeBuffer1: COMMON -> COPY_DEST
// - nativeBuffer0 -> nativeBuffer2
//   - nativeBuffer0: COPY_DEST -> GENERIC_READ
//   - nativeBuffer2: COMMON -> COPY_DEST
// - nativeBuffer2 -> outputBuffer2
//   - nativeBuffer2: COPY_DEST -> GENERIC_READ
//   - outputBuffer2: COPY_DEST -> COPY_DEST [omitted]

var barrier00 = D3D12_RESOURCE_BARRIER()
barrier00.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
barrier00.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
barrier00.Transition.pResource = nil // nativeBuffer0
barrier00.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
barrier00.Transition.StateBefore = D3D12_RESOURCE_STATE_COMMON
barrier00.Transition.StateAfter = D3D12_RESOURCE_STATE_COPY_DEST

// Next, create a utility function to minimize the boilerplate of creating
// barrier structs multiple times.

// Helper function for creating barriers.
func createBarrier(
  resource: SwiftCOM.ID3D12Resource,
  stateBefore: D3D12_RESOURCE_STATES,
  stateAfter: D3D12_RESOURCE_STATES
) -> D3D12_RESOURCE_BARRIER {
  // Specify the type of barrier.
  var output = D3D12_RESOURCE_BARRIER()
  output.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
  output.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
  
  // Specify the transition's parameters.
  try! resource.perform(
    as: WinSDK.ID3D12Resource.self
  ) { pUnk in
    output.Transition.pResource = pUnk
  }
  output.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
  output.Transition.StateBefore = stateBefore
  output.Transition.StateAfter = stateAfter
  
  // Return the barrier.
  return output
}

// Test out the utility function.
do {
  let barrier = createBarrier(
    resource: nativeBuffer0.d3d12Resource,
    stateBefore: D3D12_RESOURCE_STATE_COMMON,
    stateAfter: D3D12_RESOURCE_STATE_COPY_DEST)
}

// Next, encode a full copy command onto the command list. Commit the command
// list onto the command queue, then wait until it has completed. Verify that
// the code doesn't crash.

// Copy command: inputBuffer0 -> nativeBuffer0
do {
  // Create the barriers.
  let barrier = createBarrier(
    resource: nativeBuffer0.d3d12Resource,
    stateBefore: D3D12_RESOURCE_STATE_COMMON,
    stateAfter: D3D12_RESOURCE_STATE_COPY_DEST)
  let barriers: [D3D12_RESOURCE_BARRIER] = [barrier]
  
  // Encode the barriers.
  try! commandList.ResourceBarrier(
    UInt32(barriers.count),
    barriers)
  
  // Encode the copy command.
  try! commandList.CopyResource(
    nativeBuffer0.d3d12Resource,
    inputBuffer0.d3d12Resource)
}

// Copy command: inputBuffer1 -> nativeBuffer1
do {
  // Create the barriers.
  let barrier = createBarrier(
    resource: nativeBuffer1.d3d12Resource,
    stateBefore: D3D12_RESOURCE_STATE_COMMON,
    stateAfter: D3D12_RESOURCE_STATE_COPY_DEST)
  let barriers: [D3D12_RESOURCE_BARRIER] = [barrier]
  
  // Encode the barriers.
  try! commandList.ResourceBarrier(
    UInt32(barriers.count),
    barriers)
  
  // Encode the copy command.
  try! commandList.CopyResource(
    nativeBuffer1.d3d12Resource,
    inputBuffer1.d3d12Resource)
}

// Copy command: nativeBuffer0 -> nativeBuffer2
do {
  // Create the barriers.
  let barrier0 = createBarrier(
    resource: nativeBuffer0.d3d12Resource,
    stateBefore: D3D12_RESOURCE_STATE_COPY_DEST,
    stateAfter: D3D12_RESOURCE_STATE_COPY_SOURCE)
  let barrier2 = createBarrier(
    resource: nativeBuffer2.d3d12Resource,
    stateBefore: D3D12_RESOURCE_STATE_COMMON,
    stateAfter: D3D12_RESOURCE_STATE_COPY_DEST)
  let barriers: [D3D12_RESOURCE_BARRIER] = [barrier0, barrier2]
  
  // Encode the barriers.
  try! commandList.ResourceBarrier(
    UInt32(barriers.count),
    barriers)
  
  // Encode the copy command.
  try! commandList.CopyResource(
    nativeBuffer2.d3d12Resource,
    nativeBuffer0.d3d12Resource)
}

// Copy command: nativeBuffer2 -> outputBuffer2
do {
  let barrier = createBarrier(
    resource: nativeBuffer2.d3d12Resource,
    stateBefore: D3D12_RESOURCE_STATE_COPY_DEST,
    stateAfter: D3D12_RESOURCE_STATE_COPY_SOURCE)
  let barriers: [D3D12_RESOURCE_BARRIER] = [barrier]
  
  // Encode the barriers.
  try! commandList.ResourceBarrier(
    UInt32(barriers.count),
    barriers)
  
  // Encode the copy command.
  try! commandList.CopyResource(
    outputBuffer2.d3d12Resource,
    nativeBuffer2.d3d12Resource)
}

// Run the commands on the GPU.
commandQueue.commit(commandList)
commandQueue.flush()

// Check the data in the output buffer.
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
    print("outputBuffer[\(slotID)] = \(value2)")
  }
}



// ## Sixth Step
//
// Activate the debug layer in DirectX. Try omitting all resource barriers.
// Mess with the commands by using 'COMMON' as the source state. Either the
// code should crash, or the output buffer should have incorrect data.
//
// After this step is complete, I should purge the 'main' file to a gist.
// Incorporate resource state tracking into the 'Buffer' API, and write new
// tests for this functionality from scratch.
//
// After that task, I can return to focusing on a 'hello world' compute shader.

// ## Known Information about the Debug Layer
//
// Most commands in the DirectX spec have specific errors related to the debug
// layer. Without the debug layer, these errors don't trigger. One particularly
// relevant error involves resource barriers.
//
// The first 3DGEP tutorial mentioned and invoked the debug layer.
//
// The DirectX spec doesn't reference the 'ID3D12Debug' object directly.
// Microsoft's online documentation doesn't describe it in much detail, either.
// This makes it difficult to understand the purpose and/or how to use the
// debug layer.
//
// There are 7 iterations of the 'ID3D12Debug' interface. Some other interfaces,
// such as 'ID3D12DebugCommandList' and 'ID3D12DebugDevice', do not inherit
// from the non-debug versions. This fact differs from the Metal API design,
// where debug versions of API objects conform to the same protocol as the
// vanilla objects.
//
// The DirectX debug layer is different from the Metal validation layer. I am
// unfamiliar with the purpose of all the objects. Therefore, I am going to read
// up on how to instantiate each one.

// ## ID3D12Debug
//
// This looks like the only component of the API represented in SwiftCOM.
// Therefore, I probably won't actually use any of the other interfaces.
//
// Initializer: D3D12GetDebugInterface()
//
// Instance method: EnableDebugLayer()
//
// ## ID3D12InfoQueue
//
// Most instance members are ported in SwiftCOM. It is created by calling
// 'IUnknown::QueryInterface' on 'ID3D12Device', which sounds like a strange
// way to create an object. Have I seen this before?
//
// ## IDXGIDebug
//
// Not part of the 'direct3d-12-sdklayers-interfaces' document, but potentially
// relevant.
//
// Initializer: DXGIGetDebugInterface1()
//
// Instance method: ReportLiveObjects(GUID, DXGI_DEBUG_RLO_FLAGS)

// Useful advice about how to initialize several debug interfaces:
// http://gamedev.net/forums/topic/672268-d3d12-debug-layers-how-to-get-id3d12debugdevice/5255763/
//
// Steps:
// 1) Enable the debug layer
// 2) Create the regular device, command queue, command list
// 3) Extract the debug versions of each object through 'QueryInterface'
//
// The QueryInterface path might mean a COM object conforms to multiple
// interfaces. It doesn't look like ID3D12DebugDevice inherits from
// ID3D12Device. It makes sense that you'd need a special technique to cast
// something between these two types.

print()
print("Debug layer not initialized.")
print(device.d3d12Device)

let debugInterface: SwiftCOM.ID3D12Debug =
try! D3D12GetDebugInterface()
print()
print(debugInterface)
print(device.d3d12Device)

try! debugInterface.EnableDebugLayer()
print()
print(debugInterface)
print(device.d3d12Device)

#endif

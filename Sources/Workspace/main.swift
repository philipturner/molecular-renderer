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

// On to the next task. Before doing it, remind myself:
// - What is the ultimate goal?
// - What is the next step after this one, toward the ultimate goal?
//
// Task 1: How do I "bind buffers" to the root signature?
// Task 2: What are the UAV barriers and should resources explicitly transition
//         to the UAV state?



// ## Task 1
//
// The root signature is specified in HLSL. It declares that:
// - The buffer at location 'u0' is UAV.
// - The buffer at location 'u1' is UAV.
// - The buffer at location 'u2' is UAV.
//
// Here is how the root signature and PSO are initialized:
// - Compile the shader source code.
// - Extract the root signature and shader blobs.
// - Call 'ID3D12Device.CreateRootSignature' on the root signature blob.
// - Fill a PSO descriptor with:
//   - The shader blob.
//   - The root signature object.
//   - An absence of a cached pipeline state.
// - Call 'ID3D12Device.CreatePipelineState' on the descriptor.
//
// Questions:
// - How do I bind the buffers to the command list?
// - How do I bind the pipeline state?
// - Must the root signature be explicitly bound as well?
//
// Start the search by reading through the 3DGEP tutorials and reference code.
// Then, finish off the search by reading Microsoft's online documentation.
//
// D3D12_VERTEX_BUFFER_VIEW exists.
// D3D12_INDEX_BUFFER_VIEW exists.
// D3D12_DEPTH_STENCIL_VIEW_DESC & device->CreateDepthStencilView, m_DSVHeap
//   relies on CPU descriptor handle.
// commandList->ClearDepthStencilView(D3D12_CPU_DESCRIPTOR_HANDLE dsv)
//
// commandList->SetPipelineState(...)
// commandList->SetGraphicsRootSignature(...)
// commandList->IASetVertexBuffers(m_VertexBufferView)
// commandList->IASetIndexBuffer(m_IndexBufferView)
// commandList->DrawIndexedInstanced(...)
//
// SetGraphicsDynamicConstantBuffer(uint32_t index, void* data)
//   allocate space in UploadBuffer "heap"
//   copy data from pointer to D3D resource
//   ID3D12GraphicsCommandList::SetGraphicsRootConstantBufferView
//   using root parameter index and GPU virtual address
//
// SetShaderResourceView
//   just uses the dynamic descriptor heap helper
//   resource must be under a 'DESCRIPTOR_TABLE' root parameter
//
// CommitStagedDescriptorsForDraw
//   commandList.SetDescriptorHeap(...)
//   device->CopyDescriptors(...)
//
// CopyDescriptor
//   commandList.SetDescriptorHeap(...)
//   device->CopyDescriptorsSimple(CPU handle, CPU descriptor)
//
// Additional notes upon inspecting CommandList.cpp:
//   ID3D12GraphicsCommandList::SetPipelineState(pipelineState.Get())
//   ID3D12GraphicsCommandList::SetComputeRootSignature(m_RootSignature)
//   SetUnorderedAccessView just does the descriptor table stuff, not what I'm
//     looking for.
//   ID3D12GraphicsCommandList::Dispatch(numGroupsX, numGroupsY, numGroupsZ)
//   ID3D12GraphicsCommandList::SetDescriptorHeaps(uint32_t count, void *heaps)
//
// Riccardo Loggini compute shaders tutorial:
// - Binds a texture to a descriptor table
// - Set the "descriptor heaps" (sic) of a command list
// - Creates a UAV desc on the CPU side for the texture
// - Encodes a barrier to transition the texture to UAV
// - Fetches a CPU descriptor handle from a heap, presumably for the UAV
//
// device->CreateUnorderedAccessView(myTexture.Get(), nullptr, uavDesc,
//   myHeapUavDescriptor.GetDescriptorHandle());
// copies the descriptor between two CPU handles
// m_d3d12CommandList->SetComputeRootDescriptorTable(0, GPU descriptor handle)

// I still need more information about resource binding. Check Microsoft's
// online documentation.
//
// ID3D12GraphicsCommandList::SetPipelineState
// - programs most of the fixed-function state of the GPU pipeline
// ID3D12GraphicsCommandList::SetComputeRootSignature
// - sets the layout of the compute root signaturer
// ID3D12GraphicsCommandList::ResourceBarrier
// ID3D12GraphicsCommandList::SetComputeRootUnorderedAccessView
// ID3D12GraphicsCommandList::SetComputeRootUnorderedAccessView
// ID3D12GraphicsCommandList::SetComputeRootUnorderedAccessView
// - sets a CPU descriptor handle for the UAV resource in the root signature
// ID3D12GraphicsCommandList::Dispatch
// - Microsoft documentation looks wrong / misworded
// ID3D12GraphicsCommandList::Close
//
// Functions for creating the GPU virtual address / CPU descriptor handle...
// https://learn.microsoft.com/en-us/windows/win32/direct3d12/using-descriptors-directly-in-the-root-signature
//
// Looks like it really is as easy as specifying the GPU address. Let's see if
// we can do that and bypass the DirectX debug layer that demands a resource
// state transition.



// Before that, clean up the process of initializing a shader. There's
// boilerplate code in the previous reference that ought to go into a utility
// class.

// TODO: Change ShaderBytecode to ShaderDescriptor, but make the descriptor
// and the Shader initializer internal. Change 'Compiler' to just
// 'DirectXDevice', and put 'compile' in an 'extension'. Keep all of that, as
// well as the 'dxcompiler_compile' reference, in the same file as 'Shader'.
//
// And finally, change DirectXDevice to just Device. This brings it closer to
// merging with the Metal backend in the future.
//
// Remove '.compile' and just make it a public API of ShaderDescriptor? There
// is something interesting about one-line functions to initialize an object.
// It creates less code on the front-end. But from an API design standpoint,
// it would be more consistent to have everything made with a descriptor.
//
// What is the paradigm for MM4?
// - MM4ForceField.init(descriptor:)
// - MM4Parameters.init(descriptor:)
// - MM4RigidBody.init(descriptor:)
//
// It's valid to have a descriptor where the user sets one or no options.
//
// How about this rule:
// - If only a single variable is required, and it's obvious, the initializer
//   uses that. I had several nested functions in code that just required the
//   'device'.
//   - The code for macOS just uses this rule in internal initializers.
//   - Public initializers should always use a descriptor.
// - If two or more variables are required, always use a descriptor. Even if
//   'compile' looked familiar in previous code. Based on judgment, sometimes
//   use a descriptor if there's just one variable.
//
// Task 1: Fix the existing code in the helpers.
// Task 2: Augment the 'Shader' class, making the blobs transient and instead
//         exposing DirectX API objects to the public API.
//
// Remember: After all of this "Hello world" compute stuff is done, the next
// goal will be to merge the DirectX and Metal helper classes. At least for
// GPU compute work. After that's done, we can take steps to incorporate UI
// or app launching code on Windows.

#endif

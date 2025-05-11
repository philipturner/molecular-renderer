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
print(shaderBytecode)



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



#if false

// ## Third Step
//
// Create the buffer objects and descriptors/handles (if needed).
//
// buffer0, buffer1:
//   D3D12_HEAP_TYPE_UPLOAD
//   D3D12_RESOURCE_STATE_GENERIC_READ
// buffer2:
//   D3D12_HEAP_TYPE_READBACK
//   D3D12_RESOURCE_STATE_COPY_DEST

// Utility function for creating a committed resource.
func createHeapProperties(
  type: D3D12_HEAP_TYPE
) -> D3D12_HEAP_PROPERTIES {
  var heapProperties = D3D12_HEAP_PROPERTIES()
  heapProperties.Type = type
  heapProperties.CPUPageProperty = D3D12_CPU_PAGE_PROPERTY_UNKNOWN
  heapProperties.MemoryPoolPreference = D3D12_MEMORY_POOL_UNKNOWN
  heapProperties.CreationNodeMask = 0
  heapProperties.VisibleNodeMask = 0
  
  return heapProperties
}

// Utility function for creating a committed resource.
func createResourceDesc(size: Int) -> D3D12_RESOURCE_DESC {
  var resourceDesc = D3D12_RESOURCE_DESC()
  resourceDesc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER
  resourceDesc.Alignment = 0
  resourceDesc.Width = UINT64(size)
  resourceDesc.Height = 1
  resourceDesc.DepthOrArraySize = 1
  resourceDesc.MipLevels = 1
  resourceDesc.Format = DXGI_FORMAT_UNKNOWN
  resourceDesc.SampleDesc = DXGI_SAMPLE_DESC(Count: 1, Quality: 0)
  resourceDesc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR
  resourceDesc.Flags = D3D12_RESOURCE_FLAG_NONE
  
  return resourceDesc
}

// Create an input buffer.
func createInputBuffer(size: Int) -> SwiftCOM.ID3D12Resource {
  let heapProperties = createHeapProperties(type: D3D12_HEAP_TYPE_UPLOAD)
  let resourceDesc = createResourceDesc(size: size)
  
  let d3d12Device = device.d3d12Device
  return try! d3d12Device.CreateCommittedResource(
    heapProperties,
    D3D12_HEAP_FLAG_NONE,
    resourceDesc,
    D3D12_RESOURCE_STATE_GENERIC_READ,
    nil)
}

// Create an output buffer.



// ## Fourth Step
//
// Upload the input data to the GPU-native buffer allocations.

#endif

let bufferType: BufferType = .output
let resourceStates = bufferType.resourceStates
print(resourceStates)



// Next step: encapsulate the above code into a utility of MolecularRenderer.
//
// Object name: Buffer (later on, we will have a separate class for Texture)
//
// Enumeration allows selection between Input, Native, Output.
//
// Descriptor takes the following arguments:
// - device: DirectXDevice
// - size: heap + resource allocation size in bytes
// - type: enumeration (specified above)
//
// The object has utility functions for inputting and outputting data. These
// functions check whether the object's type is compatible with such an
// operation.
//
// The object may have utilities regarding descriptors, once we get there.



#endif

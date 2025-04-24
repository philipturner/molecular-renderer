// Next steps:
// - Access the GPU.
//   - Modify it to get Metal rendering. [DONE]
//   - Clean up and simplify the code as much as possible. [DONE]
//   - Get timestamps synchronizing properly (moving rainbow banner
//     scene). [DONE]
// - Repeat the same process with COM / D3D12 on Windows.
//   - Get some general experience with C++ DirectX sample code.
//   - Modify the files one-by-one to support Windows.

#if os(macOS)
import Metal
import MolecularRenderer

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
import FidelityFX
import SwiftCOM
import WinSDK

// MARK: - DirectX Experimentation

// Choose the best GPU out of the two that appear.
func createAdapter(
  factory: SwiftCOM.IDXGIFactory4
) -> SwiftCOM.IDXGIAdapter4 {
  var adapters: [SwiftCOM.IDXGIAdapter4] = []
  while true {
    let adapterID = adapters.count
    let adapter: SwiftCOM.IDXGIAdapter4? =
      try? factory.EnumAdapters(UInt32(adapterID)).QueryInterface()
    guard let adapter else {
      break
    }
    adapters.append(adapter)
  }

  // Choose the GPU with the greatest amount of memory. This is a relatively
  // crude heuristic for finding the fastest GPU.
  var maxAdapter: SwiftCOM.IDXGIAdapter4?
  var maxAdapterMemory: Int = .zero
  for adapterID in adapters.indices {
    let adapter = adapters[adapterID]
    let description = try! adapter.GetDesc()
    let dedicatedVideoMemory = description.DedicatedVideoMemory

    if dedicatedVideoMemory > maxAdapterMemory {
      maxAdapter = adapter
      maxAdapterMemory = Int(dedicatedVideoMemory)
    }
  }

  guard let maxAdapter else {
    fatalError("Could not find the fastest GPU.")
  }
  return maxAdapter
}

let factory: SwiftCOM.IDXGIFactory4 =
  try! CreateDXGIFactory2(UInt32(DXGI_CREATE_FACTORY_DEBUG))
print(factory)

let adapter = createAdapter(factory: factory)
print(adapter)

let device: SwiftCOM.ID3D12Device =
  try! D3D12CreateDevice(adapter, D3D_FEATURE_LEVEL_12_0)
print(device)

var commandQueueDesc = D3D12_COMMAND_QUEUE_DESC()
commandQueueDesc.Type = D3D12_COMMAND_LIST_TYPE_COMPUTE
let commandQueue: SwiftCOM.ID3D12CommandQueue =
  try! device.CreateCommandQueue(commandQueueDesc)
print(commandQueue)



// MARK: - FidelityFX Experimentation

// Set the backend header.
var createBackend = UnsafeMutablePointer<ffxCreateBackendDX12Desc>
  .allocate(capacity: 1)
createBackend.pointee.header.type = UInt64(
  FFX_API_CREATE_CONTEXT_DESC_TYPE_BACKEND_DX12)
createBackend.pointee.header.pNext = nil

do {
  // Retrieve the DirectX device.
  //
  // I did not balance this with a call to `IUnknown::Release`, so something
  // bad is probably going to happen eventually. I would like to wait until
  // after the `ffxContext` is created. Otherwise, semantically, the
  // device could be deallocated before reaching that function.
  let iid = SwiftCOM.ID3D12Device.IID
  let interface = try! device.QueryInterface(iid: iid)
  let device = interface!.assumingMemoryBound(to: WinSDK.ID3D12Device.self)
  createBackend.pointee.device = device
}

// Set the upscale header.
var createUpscale = UnsafeMutablePointer<ffxCreateContextDescUpscale>
  .allocate(capacity: 1)
createUpscale.pointee.header.type = UInt64(
  FFX_API_CREATE_CONTEXT_DESC_TYPE_UPSCALE)
createBackend.withMemoryRebound(
  to: ffxApiHeader.self, capacity: 1
) { pointer in
  createUpscale.pointee.header.pNext = pointer
}

do {
  // Invert the depth, but keep the range at [1, 0]. This is for compatibility
  // with the Metal implementation, which uses 'isDepthReversed = true'.
  createUpscale.pointee.flags =
  UInt32(FFX_UPSCALE_ENABLE_DEPTH_INVERTED.rawValue)

  // Set the input dimensions as 480x480.
  let rayTracedTextureSize: Int = 480
  var rayTracedDimensions = FfxApiDimensions2D()
  rayTracedDimensions.width = UInt32(rayTracedTextureSize)
  rayTracedDimensions.height = UInt32(rayTracedTextureSize)
  createUpscale.pointee.maxRenderSize = rayTracedDimensions

  // Set the output dimensions as 1440x1440.
  let upscaledSize: Int = 1440
  var upscaledDimensions = FfxApiDimensions2D()
  upscaledDimensions.width = UInt32(upscaledSize)
  upscaledDimensions.height = UInt32(upscaledSize)
  createUpscale.pointee.maxUpscaleSize = upscaledDimensions
}

// Set the callback to crash on all warnings.
createUpscale.pointee.fpMessage = { type, message in
  print("[FidelityFX] Encountered message of type \(type).")

  if let message {
    let string = String(decodingCString: message, as: UTF16.self)
    print("[FidelityFX] \(string)")
  } else {
    print("[FidelityFX] Message was a null pointer.")
  }
  fatalError()
}

// Create the FFX object context.
var upscaleContext: ffxContext? = nil
createUpscale.withMemoryRebound(
  to: ffxApiHeader.self, capacity: 1
) { pointer in
  let error = ffxCreateContext(
    &upscaleContext, pointer, nil)
  guard error == 0 else {
    fatalError("Failed to create context. Received error code \(error).")
  }
}
print(upscaleContext!)



// MARK: - DXC Experimentation

struct ShaderDescriptor {
  var useStructuredBuffers: Bool = false
}

struct Shader {
  var useStructuredBuffers: Bool
  
  init(descriptor: ShaderDescriptor) {
    self.useStructuredBuffers = descriptor.useStructuredBuffers
  }
  
  func createSource() -> String {
    // Decide which variant of the code to compile.
    var functionBody: String
    if useStructuredBuffers {
      functionBody = createStructuredBuffers()
    } else {
      functionBody = createRawBuffers()
    }
    
    // Bring together the entire source string.
    return """
    //--------------------------------------------------------------------------------------
    // File: BasicCompute11.hlsl
    //
    // This file contains the Compute Shader to perform array A + array B
    //
    // Copyright (c) Microsoft Corporation.
    // Licensed under the MIT License (MIT).
    //--------------------------------------------------------------------------------------
    
    \(functionBody)
    """
  }
  
  func createStructuredBuffers() -> String {
    """
    struct BufType
    {
        int i;
        float f;
    };
    
    StructuredBuffer<BufType> Buffer0 : register(t0);
    StructuredBuffer<BufType> Buffer1 : register(t1);
    RWStructuredBuffer<BufType> BufferOut : register(u0);
    
    [numthreads(1, 1, 1)]
    void main( uint3 DTid : SV_DispatchThreadID )
    {
        BufferOut[DTid.x].i = Buffer0[DTid.x].i + Buffer1[DTid.x].i;
        BufferOut[DTid.x].f = Buffer0[DTid.x].f + Buffer1[DTid.x].f;
    }
    
    """
  }
  
  func createRawBuffers() -> String {
    """
    hjk;
    
    ByteAddressBuffer Buffer0 : register(t0);
    ByteAddressBuffer Buffer1 : register(t1);
    RWByteAddressBuffer BufferOut : register(u0);

    [numthreads(1, 1, 1)]
    void main( uint3 DTid : SV_DispatchThreadID )
    {
        int i0 = asint( Buffer0.Load( DTid.x*8 ) );
        float f0 = asfloat( Buffer0.Load( DTid.x*8+4 ) );
        int i1 = asint( Buffer1.Load( DTid.x*8 ) );
        float f1 = asfloat( Buffer1.Load( DTid.x*8+4 ) );
        
        BufferOut.Store( DTid.x*8, asuint(i0 + i1) );
        BufferOut.Store( DTid.x*8+4, asuint(f0 + f1) );
    }
    
    """
  }
}

// Pausing progress on the C utility for now.
/*

// Set up the shader.
var shaderDesc = ShaderDescriptor()
shaderDesc.useStructuredBuffers = true
var shader = Shader(descriptor: shaderDesc)

// Call the C symbol from the DXC wrapper library.
let shaderSource = shader.createSource()
let returnValue = function(
  shaderSource, UInt32(shaderSource.count))
print(returnValue)

*/

// Before creating a compute shader, you need a root signature.
// Guide: logins.github.io/graphics/2020/10/31/D3D12ComputeShaders.html
//
// Resources in HLSL:
// - RWBuffer
//   - RWStructuredBuffer<>
//   - RWByteAddressBuffer
// - RWTexture
// Resources in the DirectX API:
// - Unordered access resource, can be read/written from multiple GPU threads
// - Unordered access view
//   - Referenced buffer
//   - Referenced texture
//   - Specify usage in compute pipeline
//   - Ability to perform thread-safe reading and
// - UAV loads
//   - 8-bit scalar types
//   - 16-bit scalar types
//   - 32-bit scalar types
//   - 4x8-bit vector types
//   - 4x16-bit vector types
//   - 4x32-bit vector types
// - Optional UAV load formats supported on the GTX 970:
//   - TODO
// - Resource heap tier 1: all resources in a heap must be the same type.
//   - [Mutually exclusive category] All buffers
//   - [Mutually exclusive category] All non-render textures
//   - [Mutually exclusive category] Render target textures

// Reproducing code from:
// https://learn.microsoft.com/en-us/windows/win32/direct3d12/typed-unordered-access-view-loads
//
// D3D12_FEATURE_DATA_ARCHITECTURE1(
//   NodeIndex: 0,
//   TileBasedRenderer: false,
//   UMA: false,
//   CacheCoherentUMA: false,
//   IsolatedMMU: true)
// D3D12_FEATURE_DATA_D3D12_OPTIONS(
//   DoublePrecisionFloatShaderOps: true,
//   OutputMergerLogicOp: true,
//   MinPrecisionSupport: __C.D3D12_SHADER_MIN_PRECISION_SUPPORT(rawValue: 0),
//   TiledResourcesTier: __C.D3D12_TILED_RESOURCES_TIER(rawValue: 3),
//   ResourceBindingTier: __C.D3D12_RESOURCE_BINDING_TIER(rawValue: 3),
//   PSSpecifiedStencilRefSupported: false,
//   TypedUAVLoadAdditionalFormats: true,
//   ROVsSupported: true,
//   ConservativeRasterizationTier: __C.D3D12_CONSERVATIVE_RASTERIZATION_TIER(rawValue: 1),
//   MaxGPUVirtualAddressBitsPerResource: 40,
//   StandardSwizzle64KBSupported: false,
//   CrossNodeSharingTier: __C.D3D12_CROSS_NODE_SHARING_TIER(rawValue: 0),
//   CrossAdapterRowMajorTextureSupported: false,
//   VPAndRTArrayIndexFromAnyShaderFeedingRasterizerSupportedWithoutGSEmulation: true,
//   ResourceHeapTier: __C.D3D12_RESOURCE_HEAP_TIER(rawValue: 1))
// D3D12_FEATURE_DATA_D3D12_OPTIONS1(
//   WaveOps: true,
//   WaveLaneCountMin: 32,
//   WaveLaneCountMax: 32,
//   TotalLaneCount: 1664,
//   ExpandedComputeResourceStates: true,
//   Int64ShaderOps: true)
// D3D12_FEATURE_DATA_D3D12_OPTIONS3(
//   CopyQueueTimestampQueriesSupported: true,
//   CastingFullyTypedFormatSupported: true,
//   WriteBufferImmediateSupportFlags: __C.D3D12_COMMAND_LIST_SUPPORT_FLAGS(rawValue: 127),
//     This includes all possible values for D3D12_COMMAND_LIST_SUPPORT_FLAGS.
//   ViewInstancingTier: __C.D3D12_VIEW_INSTANCING_TIER(rawValue: 2),
//   BarycentricsSupported: false)
// D3D12_FEATURE_DATA_D3D12_OPTIONS4(
//   MSAA64KBAlignedTextureSupported: true,
//   SharedResourceCompatibilityTier: __C.D3D12_SHARED_RESOURCE_COMPATIBILITY_TIER(rawValue: 2),
//     DXGI 8-bit scalar types
//     DXGI 16-bit scalar types
//     DXGI 32-bit scalar types
//     DXGI 2x8-bit vector types
//     DXGI 2x16-bit vector types
//     DXGI 4x8-bit vector types
//     DXGI 4x16-bit vector types
//     DXGI rgb10a2 packed format
//   Native16BitShaderOpsSupported: false)
//     There is no hardware support for 16-bit floating point and 16-bit integer
//     operations, except perhaps packing 16-bit integers into a 32-bit register.
// D3D12_FEATURE_DATA_D3D12_OPTIONS5(
//   SRVOnlyTiledResourceTier3: true,
//   RenderPassesTier: __C.D3D12_RENDER_PASS_TIER(rawValue: 0),
//     Render passes are provided via software emulation.
//   RaytracingTier: __C.D3D12_RAYTRACING_TIER(rawValue: 0))
//     DirectX API for ray tracing is not supported (irrelevant to my
//     application of pure software ray tracing).
// D3D12_FEATURE_DATA_GPU_VIRTUAL_ADDRESS_SUPPORT(
//   MaxGPUVirtualAddressBitsPerResource: 40,
//   MaxGPUVirtualAddressBitsPerProcess: 40)

// TODO: Query the remaining features, and finally, the types of UAV loads
// supported.
//
// Resume investigation with these links in the browser:
// https://logins.github.io/graphics/2020/10/31/D3D12ComputeShaders.html#unordered-access-resources
// https://logins.github.io/graphics/2020/07/31/DX12ResourceHandling.html
// https://learn.microsoft.com/en-us/windows/win32/direct3d12/typed-unordered-access-view-loads
// https://learn.microsoft.com/en-us/windows/win32/direct3d12/capability-querying



// Executes the code currently in the function, and prints the result to the
// console for your recording.
func queryCapability(device: SwiftCOM.ID3D12Device) {
  var featureSupport = D3D12_FEATURE_DATA_D3D12_OPTIONS5()
  try! device.CheckFeatureSupport(
    D3D12_FEATURE_D3D12_OPTIONS5,
    &featureSupport,
    UInt32(MemoryLayout<D3D12_FEATURE_DATA_D3D12_OPTIONS5>.stride))
  print(featureSupport)
  
  print("Hello, world.")
}
queryCapability(device: device)

#endif

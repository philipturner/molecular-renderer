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
//   - See the code below.
//   - All of the formats except 16-bit packed color formats.
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
// D3D12_FEATURE_DATA_EXISTING_HEAPS(
//   Supported: true)
// D3D12_FEATURE_DATA_FEATURE_LEVELS(
//   NumFeatureLevels: 10,
//   pFeatureLevelsRequested: Optional(0x00000199192594b0),
//   MaxSupportedFeatureLevel: __C.D3D_FEATURE_LEVEL(rawValue: 49408))
//     D3D_FEATURE_LEVEL_12_1
// D3D12_FEATURE_DATA_GPU_VIRTUAL_ADDRESS_SUPPORT(
//   MaxGPUVirtualAddressBitsPerResource: 40,
//   MaxGPUVirtualAddressBitsPerProcess: 40)
// D3D12_FEATURE_DATA_ROOT_SIGNATURE(
//   HighestVersion: __C.D3D_ROOT_SIGNATURE_VERSION(rawValue: 2))
//     Version 1.1
// D3D12_FEATURE_DATA_SERIALIZATION(
//   NodeIndex: 0,
//   HeapSerializationTier: __C.D3D12_HEAP_SERIALIZATION_TIER(rawValue: 0))
//     Tier 0, meaning heap serialization is not supported.
// D3D12_FEATURE_DATA_SHADER_CACHE(
//   SupportFlags: __C.D3D12_SHADER_CACHE_SUPPORT_FLAGS(rawValue: 3))
//     Supports CachedPSO member of the compute pipeline descriptor.
//     Supports application-controlled PSO grouping and caching.
//     Does not support OS-managed shader cache, in any form.
//     Does not support 'DRIVER_MANAGED_CACHE' (not documented).
//     Does not support 'SHADER_CONTROL_CLEAR' (not documented).
//     Does not support 'SHADER_SESSION_DELETE' (not documented).
//     This is interesting, because we know Metal uses a system shader cache
//     on Apple platforms. Meanwhile, DXC is open-source and might not have
//     access to a proprietary built-in cache from the Windows OS.
// D3D12_FEATURE_DATA_SHADER_MODEL(
//   HighestShaderModel: __C.D3D_SHADER_MODEL(rawValue: 101)
//     Shader Model 6.5
//     Strange. According to Wikipedia, Shader Model 6.8 just barely includes
//     Maxwell 2+ and RDNA 1+ in the list of supported architectures. However,
//     Shader Model 6.6 requires WDDM 3.0 from Windows 11. Perhaps it reports
//     Shader Model 6.5 because it is running under Windows 10.
//
// Shader Model 6.6 introduces:
// - 64-bit and floating point atomics (not needed)
// - Dynamic resources (looks useful)
// - IsHelperLane() (not needed because not using pixel shaders)
// - Derivative Operations (2x2 quad functionality not needed)
// - Pack/Unpack Intrinsics (interesting, but not needed)
// - WaveSize (interesting, this feature will result in a compiler warning)
// - Raytracing PAQs (not needed)
//
// Shader Model 6.6 functionality was the problem blocking Unreal Engine 5
// Nanite support on M1-series Apple GPUs.

// ## Support for Formats for UAVs
//
// Legend:
// - 2xx = TILED
// - 3xx = TILED, OUTPUT_MERGER_LOGIC_OP
// - xCx = UAV_TYPED_STORE, UAV_TYPED_LOAD
// - xFx = UAV_TYPED_STORE, UAV_TYPED_LOAD,
//         UAV_ATOMIC_UNSIGNED_MIN_OR_MAX,
//         UAV_ATOMIC_SIGNED_MIN_OR_MAX
// - xx8 = ATOMIC_EXCHANGE
// - xxF = ATOMIC_EXCHANGE, ATOMIC_COMPARE_STORE_OR_COMPARE_EXCHANGE,
//         ATOMIC_BITWISE_OPS, ATOMIC_ADD
//
// R32_FLOAT          | 1  | true  | 2C8  |
// R32_UINT           | 1  | true  | 3FF  |
// R32_SINT           | 1  | true  | 2FF  |
//
// R32G32B32A32_FLOAT | 1  | true  | 2C0  |
// R32G32B32A32_UINT  | 1  | true  | 3C0  |
// R32G32B32A32_SINT  | 1  | true  | 2C0  |
// R16G16B16A16_FLOAT | 1  | true  | 2C0  |
// R16G16B16A16_UINT  | 1  | true  | 3C0  |
// R16G16B16A16_SINT  | 1  | true  | 2C0  |
// R8G8B8A8_UNORM     | 1  | true  | 2C0  |
// R8G8B8A8_UINT      | 1  | true  | 3C0  |
// R8G8B8A8_SINT      | 1  | true  | 2C0  |
// R16_FLOAT          | 1  | true  | 2C0  |
// R16_UINT           | 1  | true  | 3C0  |
// R16_SINT           | 1  | true  | 2C0  |
// R8_UNORM           | 1  | true  | 2C0  |
// R8_UINT            | 1  | true  | 3C0  |
// R8_SINT            | 1  | true  | 2C0  |
//
// R16G16B16A16_UNORM | 1  | true  | 2C0  |
// R16G16B16A16_SNORM | 1  | true  | 2C0  |
// R32G32_FLOAT       | 1  | true  | 2C0  |
// R32G32_UINT        | 1  | true  | 3C0  |
// R32G32_SINT        | 1  | true  | 2C0  |
// R10G10B10A2_UNORM  | 1  | true  | 2C0  |
// R10G10B10A2_UINT   | 1  | true  | 3C0  |
// R11G11B10_FLOAT    | 1  | true  | 2C0  |
// R8G8B8A8_SNORM     | 1  | true  | 2C0  |
// R16G16_FLOAT       | 1  | true  | 2C0  |
// R16G16_UNORM       | 1  | true  | 2C0  |
// R16G16_UINT        | 1  | true  | 3C0  |
// R16G16_SNORM       | 1  | true  | 2C0  |
// R16G16_SINT        | 1  | true  | 2C0  |
// R8G8_UNORM         | 1  | true  | 2C0  |
// R8G8_UINT          | 1  | true  | 3C0  |
// R8G8_SNORM         | 1  | true  | 2C0  |
// R8G8_SINT          | 1  | true  | 2C0  |
// R16_UNORM          | 1  | true  | 2C0  |
// R16_SNORM          | 1  | true  | 2C0  |
// R8_SNORM           | 1  | true  | 2C0  |
// A8_UNORM           | 1  | true  | 2C0  |
// B5G6R5_UNORM       | 1  | false | 200  |
// B5G5R5A1_UNORM     | 1  | false | 200  |
// B4G4R4A4_UNORM     | 1  | false | 200  |

#if false

// Executes the code currently in the function, and prints the result to the
// console for your recording.
func queryCapability1(
  device: SwiftCOM.ID3D12Device,
  format: DXGI_FORMAT
) -> String {
  var featureSupport = D3D12_FEATURE_DATA_FORMAT_INFO()
  featureSupport.Format = format
  
  try! device.CheckFeatureSupport(
    D3D12_FEATURE_FORMAT_INFO,
    &featureSupport,
    UInt32(MemoryLayout<D3D12_FEATURE_DATA_FORMAT_INFO>.stride))
  
  return String(featureSupport.PlaneCount)
}

// Executes the code currently in the function, and prints the result to the
// console for your recording.
func queryCapability2(
  device: SwiftCOM.ID3D12Device,
  format: DXGI_FORMAT
) -> String {
  var featureSupport = D3D12_FEATURE_DATA_FORMAT_SUPPORT()
  featureSupport.Format = format
  
  try! device.CheckFeatureSupport(
    D3D12_FEATURE_FORMAT_SUPPORT,
    &featureSupport,
    UInt32(MemoryLayout<D3D12_FEATURE_DATA_FORMAT_SUPPORT>.stride))
  
  return String(featureSupport.Support1.rawValue & 0x2000000 > 0)
}

// Executes the code currently in the function, and prints the result to the
// console for your recording.
func queryCapability3(
  device: SwiftCOM.ID3D12Device,
  format: DXGI_FORMAT
) -> String {
  var featureSupport = D3D12_FEATURE_DATA_FORMAT_SUPPORT()
  featureSupport.Format = format
  
  try! device.CheckFeatureSupport(
    D3D12_FEATURE_FORMAT_SUPPORT,
    &featureSupport,
    UInt32(MemoryLayout<D3D12_FEATURE_DATA_FORMAT_SUPPORT>.stride))
  
  return String(featureSupport.Support2.rawValue, radix: 16, uppercase: true)
}

// Specify the formats.
let formatPairs: [(String, DXGI_FORMAT)] = [
  ("R32_FLOAT", DXGI_FORMAT_R32_FLOAT),
  ("R32_UINT", DXGI_FORMAT_R32_UINT),
  ("R32_SINT", DXGI_FORMAT_R32_SINT),
  
  ("R32G32B32A32_FLOAT", DXGI_FORMAT_R32G32B32A32_FLOAT),
  ("R32G32B32A32_UINT", DXGI_FORMAT_R32G32B32A32_UINT),
  ("R32G32B32A32_SINT", DXGI_FORMAT_R32G32B32A32_SINT),
  ("R16G16B16A16_FLOAT", DXGI_FORMAT_R16G16B16A16_FLOAT),
  ("R16G16B16A16_UINT", DXGI_FORMAT_R16G16B16A16_UINT),
  ("R16G16B16A16_SINT", DXGI_FORMAT_R16G16B16A16_SINT),
  ("R8G8B8A8_UNORM", DXGI_FORMAT_R8G8B8A8_UNORM),
  ("R8G8B8A8_UINT", DXGI_FORMAT_R8G8B8A8_UINT),
  ("R8G8B8A8_SINT", DXGI_FORMAT_R8G8B8A8_SINT),
  ("R16_FLOAT", DXGI_FORMAT_R16_FLOAT),
  ("R16_UINT", DXGI_FORMAT_R16_UINT),
  ("R16_SINT", DXGI_FORMAT_R16_SINT),
  ("R8_UNORM", DXGI_FORMAT_R8_UNORM),
  ("R8_UINT", DXGI_FORMAT_R8_UINT),
  ("R8_SINT", DXGI_FORMAT_R8_SINT),
  
  ("R16G16B16A16_UNORM", DXGI_FORMAT_R16G16B16A16_UNORM),
  ("R16G16B16A16_SNORM", DXGI_FORMAT_R16G16B16A16_SNORM),
  ("R32G32_FLOAT", DXGI_FORMAT_R32G32_FLOAT),
  ("R32G32_UINT", DXGI_FORMAT_R32G32_UINT),
  ("R32G32_SINT", DXGI_FORMAT_R32G32_SINT),
  ("R10G10B10A2_UNORM", DXGI_FORMAT_R10G10B10A2_UNORM),
  ("R10G10B10A2_UINT", DXGI_FORMAT_R10G10B10A2_UINT),
  ("R11G11B10_FLOAT", DXGI_FORMAT_R11G11B10_FLOAT),
  ("R8G8B8A8_SNORM", DXGI_FORMAT_R8G8B8A8_SNORM),
  ("R16G16_FLOAT", DXGI_FORMAT_R16G16_FLOAT),
  ("R16G16_UNORM", DXGI_FORMAT_R16G16_UNORM),
  ("R16G16_UINT", DXGI_FORMAT_R16G16_UINT),
  ("R16G16_SNORM", DXGI_FORMAT_R16G16_SNORM),
  ("R16G16_SINT", DXGI_FORMAT_R16G16_SINT),
  ("R8G8_UNORM", DXGI_FORMAT_R8G8_UNORM),
  ("R8G8_UINT", DXGI_FORMAT_R8G8_UINT),
  ("R8G8_SNORM", DXGI_FORMAT_R8G8_SNORM),
  ("R8G8_SINT", DXGI_FORMAT_R8G8_SINT),
  ("R16_UNORM", DXGI_FORMAT_R16_UNORM),
  ("R16_SNORM", DXGI_FORMAT_R16_SNORM),
  ("R8_SNORM", DXGI_FORMAT_R8_SNORM),
  ("A8_UNORM", DXGI_FORMAT_A8_UNORM),
  ("B5G6R5_UNORM", DXGI_FORMAT_B5G6R5_UNORM),
  ("B5G5R5A1_UNORM", DXGI_FORMAT_B5G5R5A1_UNORM),
  ("B4G4R4A4_UNORM", DXGI_FORMAT_B4G4R4A4_UNORM),
]

// Iterate over the formats.
for (description, format) in formatPairs {
  // Utility for aligning data in a table.
  func print_(_ string: String, length: Int) {
    var output = string
    while output.count < length {
      output = output + " "
    }
    print(output, terminator: " | ")
  }
  
  // Comment
  print("// ", terminator: "")
  
  // Description
  print_(description, length: 18)
  
  // Plane Count
  let capability1 = queryCapability1(device: device, format: format)
  print_(capability1, length: 2)
  
  // Typed Unordered Access View
  let capability2 = queryCapability2(device: device, format: format)
  print_(capability2, length: 5)
  
  // UAV Typed Load
  let capability3 = queryCapability3(device: device, format: format)
  print_(capability3, length: 4)
  
  // New Line
  print()
}

#endif



// Articles to investigate next, as precursor to setting up compute PSO:
// https://logins.github.io/graphics/2020/07/31/DX12ResourceHandling.html
// https://logins.github.io/graphics/2020/10/31/D3D12ComputeShaders.html#practical-usage

var rootParams = UnsafeMutablePointer<D3D12_ROOT_PARAMETER1>.allocate(capacity: 2)
var staticSamplers = UnsafeMutablePointer<D3D12_STATIC_SAMPLER_DESC>.allocate(capacity: 1)

var rootSignatureDesc = D3D12_ROOT_SIGNATURE_DESC1()
rootSignatureDesc.NumParameters = 2
rootSignatureDesc.pParameters = UnsafePointer(rootParams)
rootSignatureDesc.NumStaticSamplers = 0
rootSignatureDesc.pStaticSamplers = UnsafePointer(staticSamplers)
rootSignatureDesc.Flags = D3D12_ROOT_SIGNATURE_FLAG_NONE

var rootConstants = D3D12_ROOT_CONSTANTS()
rootConstants.ShaderRegister = 1;
rootConstants.RegisterSpace = 0;
rootConstants.Num32BitValues = 2;
rootParams[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS
rootParams[0].Constants = rootConstants
rootParams[0].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL

var rootDescriptor = D3D12_ROOT_DESCRIPTOR1()
rootDescriptor.ShaderRegister = 6;
rootDescriptor.RegisterSpace = 0;
rootParams[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_UAV
rootParams[1].Descriptor = rootDescriptor
rootParams[1].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL



// D3D12_RESOURCE_DESC
// ID3D12Device::CreateCommittedResource
// ID3D12Resource
// View object
// bind to the root signature
//
// types of resource
// - buffer
//   - constant buffer
//   - unordered access resource
// - texture
//   - unordered access texture
//   - treated in standalone blog post
//
// resource view
// - resources are stored with general purpose formats
// - switching between RGBA_FLOAT and RGBA_UINT
// - unordered access view, which supports atomic operations
//
// descriptor
// - memory storage for a resource view
// - allocated on both CPU and GPU
// - root signature
//   - uses descriptors
//     - application responsible for validity
//     - contains views
//       - reference resources
//       - reference type of usage
// - special cases:
//   - null descriptor
//   - default descriptor
//
// descriptor heaps
// - set the heap flag for "shader visible"
// - manually synchronize changes between CPU and GPU
// - use the CBV_SRC_UAV type
// - only one heap may be bound to a command list
//
// descriptor handle
// - output of method for generating view
// - wraps memory address where descriptor is stored
// - often perform pointer arithmetic
//   - query the descriptor size, usually 32-64 B
//   - move from one descriptor to another in memory
//
// copying descriptors
// - create ranges of descriptors and view objects on CPU
// - copy descriptor ranges to heap on GPU:
//   - shader visible
//   - currently bound to command list
//
// memory management
// - three types
//   - dedicated video memory
//   - dedicated system memory (inaccessible)
//   - shared system memory (slow)
// - resident when accessed, non-resident when deleted
// - wait to deallocate a resource until all dependent commands have finished
// - resources allocated in GPU virtual address space
// - DX12 manages resources to a 'subresource' granularity
//   - buffers: different linear subdivisions of memory
//   - textures: different mip levels
//
// alignment
// - allocation size is greater than resource size
// - heap resource alignment is 64 KB
// - can use D3D12_DEFAULT_RESOURCE_PLACEMENT_ALIGNMENT, or set the field to 0
// - constant buffer resources are aligned to 256 B
// - 'tight alignment' introduced in Dec 2024, but unlikely to use in my app
//
// heap types
// - residency applies at the granularity of the entire heap
// - abstracted heap types
//   - default (dedicated video memory)
//   - upload (shared system memory)
//   - readback (shared system memory)
// - resource mapping:
//   - upload heap (CPU -> GPU)
//   - default heap (GPU -> GPU)
// - custom heap types probably not useful
//
// resource allocation types
// - committed (creates entire heap to fit the resource)
// - placed (on existing heap), more lightweight resource creation method
// - reserved (not yet allocated), probably not useful
//   - virtual address space > physical memory size
//   - virtual address can be held while resource is non-resident?
//
// resource mapping
// - not trivial; "write combining is not your friend" (2013)
//   - cache coherency protocols exist between CPU cores
//   - CPU communicates with external devices through memory mapping
//   - originally, each memory access was an individual transaction (slow)
//   - write combining: reads aren't cached, but writes are temporally batched
//   - for bulk, one-way transactions (not atomics/synchronization)
//   - ensures all writes finish before the command is dispatched
// - write combined: WC looks like tungsten carbide (lol)
// - you're not supposed to read from memory that is written to
//   - x86 architecture has no notion of write-only memory
//   - all writes are flushed the instant any address is read from (perf. drop)
//   - high latency for these types of reads
// - older processors have restrictive rules
//   - writes must have specific sizes
//   - writes must have specific alignment
//   - accesses must be sequential (difficult with C compiler reordering)
// - newer processors (2002 onward) tolerate out-of-order writes
// - write contiguous blocks
//   - a small hole forces the transaction to split into two blocks
//   - write to every member of a struct, organized in order in source code

#if false
print(D3D12_DEFAULT_RESOURCE_PLACEMENT_ALIGNMENT)
print(D3D12_CONSTANT_BUFFER_DATA_PLACEMENT_ALIGNMENT)
#endif



// Querying adapter description to find amount of shared memory for uploading
// new data each frame.
//
// DXGI_ADAPTER_DESC(
//   VendorId: 4318,
//   DeviceId: 5058,
//   SubSysId: 695482434,
//   Revision: 161,
//   DedicatedVideoMemory: 4233756672,
//   DedicatedSystemMemory: 0,
//   SharedSystemMemory: 8509143040,
//   AdapterLuid: __C._LUID(LowPart: 41008, HighPart: 0))
//
// DXGI_ADAPTER_DESC1(
//   VendorId: 4318,
//   DeviceId: 5058,
//   SubSysId: 695482434,
//   Revision: 161,
//   DedicatedVideoMemory: 4233756672,
//   DedicatedSystemMemory: 0,
//   SharedSystemMemory: 8509143040,
//   AdapterLuid: __C._LUID(LowPart: 41008, HighPart: 0), Flags: 0)
//
// DXGI_ADAPTER_DESC2(
//   VendorId: 4318,
//   DeviceId: 5058,
//   SubSysId: 695482434,
//   Revision: 161,
//   DedicatedVideoMemory: 4233756672,
//   DedicatedSystemMemory: 0,
//   SharedSystemMemory: 8509143040,
//   AdapterLuid: __C._LUID(LowPart: 41008, HighPart: 0),
//   Flags: 0,
//   GraphicsPreemptionGranularity: __C.DXGI_GRAPHICS_PREEMPTION_GRANULARITY(rawValue: 0),
//   ComputePreemptionGranularity: __C.DXGI_COMPUTE_PREEMPTION_GRANULARITY(rawValue: 0))
//
// DXGI_ADAPTER_DESC3(
//   VendorId: 4318,
//   DeviceId: 5058,
//   SubSysId: 695482434,
//   Revision: 161,
//   DedicatedVideoMemory: 4233756672,
//   DedicatedSystemMemory: 0,
//   SharedSystemMemory: 8509143040,
//   AdapterLuid: __C._LUID(LowPart: 41008, HighPart: 0),
//   Flags: __C.DXGI_ADAPTER_FLAG3(rawValue: 44),
//   GraphicsPreemptionGranularity: __C.DXGI_GRAPHICS_PREEMPTION_GRANULARITY(rawValue: 0),
//   ComputePreemptionGranularity: __C.DXGI_COMPUTE_PREEMPTION_GRANULARITY(rawValue: 0))
//
// System CPU RAM:         16 GB (15.8 GB usable)
// Expected GPU RAM:       3.5-4.0 GB
// Dedicated Video Memory: 3.94 GB
// Shared System Memory:   7.92 GB

#if false
do {
  let adapterDesc = try! adapter.GetDesc()
  let adapterDesc1 = try! adapter.GetDesc1()
  let adapterDesc2 = try! adapter.GetDesc2()
  let adapterDesc3 = try! adapter.GetDesc3()
  print()
  print(adapterDesc)
  print()
  print(adapterDesc1)
  print()
  print(adapterDesc2)
  print()
  print(adapterDesc3)
}
#endif



// reference code: logins/FirstDX12Renderer/lib/3DGEP/Source/Graphics/D3D12
//
// general approach:
// - create committed resources
//   - method of ID3D12Device
//   - requests heap properties and heap flags
//   - requests resource descriptor and resource state
//   - clear value should be 'nil' for buffers?
//
// - destination ID3D12Resource
//   - heap properties:
//     - heap type: D3D12_HEAP_TYPE_DEFAULT
//     - CPU page property: D3D12_CPU_PAGE_PROPERTY_UNKNOWN
//     - memory pool preference: D3D12_MEMORY_POOL_UNKNOWN
//     - node masks: 0
//   - heap flags: D3D12_HEAP_FLAG_NONE
//   - resource desc:
//     - dimension: D3D12_RESOURCE_DIMENSION_BUFFER
//     - alignment: 0
//     - width: input byte count specified as argument
//     - height: 1
//     - depth or array size: 1
//     - mip levels: 1
//     - format: DXGI_FORMAT_UNKNOWN
//     - sample desc: (Count = 1, Quality = 0)
//     - layout: D3D12_TEXTURE_LAYOUT_ROW_MAJOR
//     - flags: D3D12_RESOURCE_FLAG_NONE
//   - resource states: D3D12_RESOURCE_STATE_COPY_DEST
//   - clear value: nil
//
// - intermediate ID3D12Resource
//   - heap properties:
//     - heap type: D3D12_HEAP_TYPE_UPLOAD
//     - CPU page property: D3D12_CPU_PAGE_PROPERTY_UNKNOWN
//     - memory pool preference: D3D12_MEMORY_POOL_UNKNOWN
//     - node masks: 0
//   - heap flags: D3D12_HEAP_FLAG_NONE
//   - resource desc:
//     - dimension: D3D12_RESOURCE_DIMENSION_BUFFER
//     - alignment: 0
//     - width: input byte count specified as argument
//     - height: 1
//     - depth or array size: 1
//     - mip levels: 1
//     - format: DXGI_FORMAT_UNKNOWN
//     - sample desc: (Count = 1, Quality = 0)
//     - layout: D3D12_TEXTURE_LAYOUT_ROW_MAJOR
//     - flags: input flags specified as argument
//   - resource states: D3D12_RESOURCE_STATE_GENERIC_READ
//   - clear value: nil
//
// - update subresources
//   - subresource data:
//     - pData: input pointer specified as argument
//     - RowPitch: input byte count specified as argument
//     - SlicePitch: input byte count specified as argument
//   - 6 different utility functions with the same name
//     - argument 0: input command list
//     - argument 1: pointer to destination ID3D12Resource
//     - argument 2: pointer to intermediate ID3D12Resource
//     - argument 3: 0 (intermediate offset)
//     - argument 4: 0 (first subresource)
//     - argument 5: 1 (number of subresources)
//     - argument 6: reference to subresource data
//   - candidate: Heap-allocating UpdateSubresources implementation
//   - candidate: Stack-allocating UpdateSubresources implementation
//   - both candidates look similar:

/*
inline UINT64 UpdateSubresources(
    _In_ ID3D12GraphicsCommandList* pCmdList,
    _In_ ID3D12Resource* pDestinationResource,
    _In_ ID3D12Resource* pIntermediate,
    UINT64 IntermediateOffset,
    _In_range_(0,D3D12_REQ_SUBRESOURCES) UINT FirstSubresource,
    _In_range_(0,D3D12_REQ_SUBRESOURCES-FirstSubresource) UINT NumSubresources,
    _In_reads_(NumSubresources) const D3D12_SUBRESOURCE_DATA* pSrcData) noexcept
    
template <UINT MaxSubresources>
inline UINT64 UpdateSubresources(
    _In_ ID3D12GraphicsCommandList* pCmdList,
    _In_ ID3D12Resource* pDestinationResource,
    _In_ ID3D12Resource* pIntermediate,
    UINT64 IntermediateOffset,
    _In_range_(0,MaxSubresources) UINT FirstSubresource,
    _In_range_(1,MaxSubresources-FirstSubresource) UINT NumSubresources,
    _In_reads_(NumSubresources) const D3D12_SUBRESOURCE_DATA* pSrcData) noexcept
*/
//
// - approach for update subresources:
//   - allocate memory with 'HeapAlloc(GetProcessHeap())'
//   - make typed pointers to 'layouts, rowSizesInBytes, NumRows'
//   - get the descriptor for the destination resource
//   - get the device of the destination resource
//   - call ID3D12Device::GetCopyableFootprints to get resource layout
//     - this is a function for sub-allocating space in heaps
//     - also gets the required size
//   - call another function for 'UpdateSubresources'
//
// - first function in the file called 'UpdateSubresources':
//   - can ignore the validation part in the source code
//   - pIntermediate->Map(0, nullptr, pData)
//   - MemcpySubresource(pData, pSrcData)
//   - pIntermediate->Unmap(0, nullptr)
//   - function exclusive to ID3D12GraphicsCommandList?
//     - pDstBuffer: pDestinationResource
//     - DstOffset: 0
//     - pSrcBuffer: pIntermediate
//     - SrcOffset: defined elsewhere in the function
//   - there is no 'ID3D12ComputeCommandList'
//     - instead, there might be some specialization with D3D12_COMMAND_LIST_TYPE
//     - direct vs. bundle
//     - compute (perhaps mutually exclusive with the rest)
//     - copy (perhaps mutually exclusive with the rest)
//   - the sample code uses COMMAND_LIST_TYPE_DIRECT
//   - typical modern GPUs supposedly have:
//     - hardware queue for graphics that maps to "DIRECT"
//     - hardware queue for compute that maps "COMPUTE"
//     - hardware queue for DMA engine that maps to "COPY"
//   - DIRECT queues and lists accept any command
//   - COMPUTE queues and lists accept only compute, copy commands
//   - COPY queues and lists accept only copy commands
//
// - utility functions using this structure:
//   - D3D12GraphicsAllocator::AllocateBufferCommittedResource
//   - D3D12GEPUtils::UpdateBufferResource
//
// That was a lot of research and external code review. Now, I can return to
// the article and fill in the gaps in its code snippets.

// Summary of the article's text (w/o the code snippets)
// - First, create an "upload buffer"
// - Map the buffer to CPU memory
//   - Declare the range of memory open for read from the CPU
//   - Set that region to 'nil' because we only want to write
//   - Gives a pointer to CPU allocated data
// - Most of the complexity in the code above, might come from subresource
//   functionality that we don't actually need.
//   - It looks silly:
//     - Heaps contain multiple resources
//     - Resources contain multiple subresources
//   - Two levels of indirection?
// - Copy to an upload heap, then a default heap

// Fences
// - Fence operation inserted into command stream before dispatching
// - Notifies the fence object, so the CPU can react
//   - CommandQueue::Signal specifies the integer value that identifies the signal
//   - Fence::GetCompletedValue can be polled until the signal is found
//   - Fence::SetEventOnCompletion is more complicated
//
// Ring buffer scenario
// - Ring buffer as way to manage upload heap
// - Frame offset queue tracks each frame
// - CPU stalls until a past frame is rendered, by waiting on a fence

// Resource state transitions
// - Manually transition a resource's state
// - Decoupled from resource binding
// - Shaders expect each specific resource to have a determined state
// - Can transition individual subresources within a resource
// - Transition barriers:
//   - Perform the state description
//   - Entered into a command list
// - 32 different possible states
// - D3D12 runtime's debug layer warns of improper state
// - Insert a D3D12_RESOURCE_UAV_BARRIER between consecutive compute commands
//
// Might be a good resource:
// https://www.3dgep.com/learning-directx-12-3/
// - Looks like a good idea to just start reading the article from the beginning
// - This is a targeted, narrowly scoped learning experience. Do not spend time
//   on lessons 1, 2, and 4 of the series. Upon completion, return to the
//   article about compute shaders by Riccardo Loggini.
// - Additional good link to keep in the browser:
// https://learn.microsoft.com/en-us/windows/win32/direct3d12/using-resource-barriers-to-synchronize-resource-states-in-direct3d-12

// First deliverable: creating a buffer.

func createHeapProperties(type: D3D12_HEAP_TYPE) -> D3D12_HEAP_PROPERTIES {
  var heapProperties = D3D12_HEAP_PROPERTIES()
  heapProperties.Type = type
  heapProperties.CPUPageProperty = D3D12_CPU_PAGE_PROPERTY_UNKNOWN
  heapProperties.MemoryPoolPreference = D3D12_MEMORY_POOL_UNKNOWN
  heapProperties.CreationNodeMask = 0
  heapProperties.VisibleNodeMask = 0
  
  return heapProperties
}

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

func createUploadBuffer(
  device: SwiftCOM.ID3D12Device
) -> SwiftCOM.ID3D12Resource {
  let heapProperties = createHeapProperties(type: D3D12_HEAP_TYPE_UPLOAD)
  let resourceDesc = createResourceDesc(size: 2 * 1024 * 1024)
  
  let resource: SwiftCOM.ID3D12Resource = try! device.CreateCommittedResource(
    heapProperties,
    D3D12_HEAP_FLAG_NONE,
    resourceDesc,
    D3D12_RESOURCE_STATE_GENERIC_READ,
    nil)
  return resource
}

func createDefaultBuffer(
  device: SwiftCOM.ID3D12Device
) -> SwiftCOM.ID3D12Resource {
  let heapProperties = createHeapProperties(type: D3D12_HEAP_TYPE_DEFAULT)
  let resourceDesc = createResourceDesc(size: 2 * 1024 * 1024)
  
  let resource: SwiftCOM.ID3D12Resource = try! device.CreateCommittedResource(
    heapProperties,
    D3D12_HEAP_FLAG_NONE,
    resourceDesc,
    D3D12_RESOURCE_STATE_COPY_DEST,
    nil)
  return resource
}

let uploadBuffer = createUploadBuffer(device: device)
let defaultBuffer = createDefaultBuffer(device: device)
print(uploadBuffer)
print(defaultBuffer)

// Second deliverable: copying the data with subresource or whatever.
do {
  let pSrcData = UnsafeMutablePointer<UInt8>.allocate(capacity: 2 * 1024 * 1024)
  let pData = try! uploadBuffer.Map(0, nil)
  guard let pData else {
    fatalError("pData was invalid.")
  }
  print(pSrcData)
  print(pData)
  
  memcpy(pData, pSrcData, 2 * 1024 * 1024)
  
  // TODO: Make the command list once you're that far along in the tutorial.
  // pCmdList->CopyBufferRegion(...)
  
  // Inspect the GPU pointer.
  let uploadGPUPtr = try! uploadBuffer.GetGPUVirtualAddress()
  let defaultGPUPtr = try! defaultBuffer.GetGPUVirtualAddress()
  print(uploadGPUPtr)
  print(defaultGPUPtr)
  
  // Remember to unmap the CPU pointer once it's no longer needed.
  try! uploadBuffer.Unmap(0, nil)
}



#endif

#if os(macOS)
import Metal
#else
import SwiftCOM
import WinSDK
#endif

// Entry point into the C library that uses the C++ API for
// DirectXShaderCompiler.
#if os(Windows)
@_silgen_name("dxcompiler_compile")
private func dxcompiler_compile(
  _ source: UnsafePointer<CChar>,
  _ sourceLength: UInt32,
  _ object: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
  _ objectLength: UnsafeMutablePointer<UInt32>,
  _ rootSignature: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
  _ rootSignatureLength: UnsafeMutablePointer<UInt32>
) -> Int32
#endif

public struct ShaderDescriptor {
  public var device: Device?
  public var source: String?
  
  public init() {
    
  }
}

/* macOS code

func createRenderPipeline(
  application: Application,
  shaderSource: String
) -> MTLComputePipelineState {
  let device = application.device
  let shaderSource = createShaderSource()
  let library = try! device.mtlDevice
    .makeLibrary(source: shaderSource, options: nil)
  
  let function = library.makeFunction(name: "renderImage")
  guard let function else {
    fatalError("Could not make function.")
  }
  let pipeline = try! device.mtlDevice
    .makeComputePipelineState(function: function)
  return pipeline
}
*/

public class Shader {
  public let d3d12PipelineState: SwiftCOM.ID3D12PipelineState
  public let d3d12RootSignature: SwiftCOM.ID3D12RootSignature
  
  public init(descriptor: ShaderDescriptor) {
    guard let device = descriptor.device,
          let source = descriptor.source else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Declare the function arguments and return values.
    let sourceCount = UInt32(source.count)
    var objectBlob: UnsafeMutablePointer<UInt8>?
    var objectLength: UInt32 = .zero
    var rootSignatureBlob: UnsafeMutablePointer<UInt8>?
    var rootSignatureLength: UInt32 = .zero
    
    // Invoke the function from the DXC wrapper.
    let errorCode = dxcompiler_compile(
      source,
      sourceCount,
      &objectBlob,
      &objectLength,
      &rootSignatureBlob,
      &rootSignatureLength)
    if errorCode != 0 {
      fatalError("dxcompiler_compile failed with error code \(errorCode).")
    }
    
    // Handle the deallocation of the blobs. For some reason, 'free' works just
    // fine, but '.deallocate' causes a crash.
    guard let objectBlob,
          let rootSignatureBlob else {
      fatalError("This should never happen.")
    }
    defer { free(objectBlob) }
    defer { free(rootSignatureBlob) }
    
    // Create the root signature.
    self.d3d12RootSignature =
    try! device.d3d12Device.CreateRootSignature(
      0, // nodeMask
      rootSignatureBlob, // pBlobWithRootSignature
      UInt64(rootSignatureLength)) // blobLengthInBytes
    
    // Specify the root signature.
    var pipelineStateDesc = D3D12_COMPUTE_PIPELINE_STATE_DESC()
    try! d3d12RootSignature.perform(
      as: WinSDK.ID3D12RootSignature.self
    ) { pUnk in
      pipelineStateDesc.pRootSignature = pUnk
    }
    
    // Specify the compute shader.
    do {
      var shaderBytecode = D3D12_SHADER_BYTECODE()
      shaderBytecode.pShaderBytecode = UnsafeRawPointer(objectBlob)
      shaderBytecode.BytecodeLength = UInt64(objectLength)
      pipelineStateDesc.CS = shaderBytecode
    }
    
    // Create the pipeline state.
    self.d3d12PipelineState = try! device.d3d12Device
      .CreateComputePipelineState(pipelineStateDesc)
  }
}

// Move this into swift-com, where it belongs.
extension SwiftCOM.ID3D12Device {
  public func CreateComputePipelineState<PSO: SwiftCOM.IUnknown>(_ Desc: D3D12_COMPUTE_PIPELINE_STATE_DESC) throws -> PSO {
    var Desc = Desc
    var iid: IID = PSO.IID
    return try PSO(pUnk: CreateComputePipelineState(&Desc, &iid))
  }
}

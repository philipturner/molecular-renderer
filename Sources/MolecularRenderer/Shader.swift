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
  _ name: UnsafePointer<UInt16>,
  _ nameLength: UInt32,
  _ object: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
  _ objectLength: UnsafeMutablePointer<UInt32>,
  _ rootSignature: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
  _ rootSignatureLength: UnsafeMutablePointer<UInt32>
) -> Int32
#endif

public struct ShaderDescriptor {
  public var device: Device?
  public var name: String?
  public var source: String?
  #if os(macOS)
  public var threadsPerGroup: SIMD3<UInt16>?
  #endif
  
  public init() {
    
  }
}

public class Shader {
  #if os(macOS)
  public let mtlComputePipelineState: MTLComputePipelineState
  public let threadsPerGroup: MTLSize
  #else
  public let d3d12PipelineState: SwiftCOM.ID3D12PipelineState
  public let d3d12RootSignature: SwiftCOM.ID3D12RootSignature
  #endif
  
  public init(descriptor: ShaderDescriptor) {
    guard let device = descriptor.device,
          let name = descriptor.name,
          let source = descriptor.source else {
      fatalError("Descriptor was incomplete.")
    }
    #if os(macOS)
    guard let threadsPerGroup = descriptor.threadsPerGroup else {
      fatalError("Descriptor was incomplete.")
    }
    #endif
    
    #if os(macOS)
    // Create the library.
    let library = try! device.mtlDevice
      .makeLibrary(source: source, options: nil)
    
    // Create the function.
    let function = library.makeFunction(name: name)
    guard let function else {
      fatalError("Could not create MTLFunction.")
    }
    
    // Create the pipeline state.
    self.mtlComputePipelineState = try! device.mtlDevice
      .makeComputePipelineState(function: function)
    
    // Store the number of threads per threadgroup.
    do {
      var mtlSize = MTLSize()
      mtlSize.width = Int(threadsPerGroup[0])
      mtlSize.height = Int(threadsPerGroup[1])
      mtlSize.depth = Int(threadsPerGroup[2])
      self.threadsPerGroup = mtlSize
    }
    #else
    // Declare the function arguments and return values.
    let sourceLength = UInt32(source.count)
    let nameLength = UInt32(name.count)
    var objectBlob: UnsafeMutablePointer<UInt8>?
    var objectLength: UInt32 = .zero
    var rootSignatureBlob: UnsafeMutablePointer<UInt8>?
    var rootSignatureLength: UInt32 = .zero
    
    print("checkpoint 0")
    
    // Call into the DXC wrapper.
    name.withCString(encodedAs: UTF16.self) { name in
      let errorCode = dxcompiler_compile(
        source,
        sourceLength,
        name,
        nameLength,
        &objectBlob,
        &objectLength,
        &rootSignatureBlob,
        &rootSignatureLength)
      if errorCode != 0 {
        fatalError("dxcompiler_compile failed with error code \(errorCode).")
      }
    }
    
    print("checkpoint 1")
    
    // Handle the deallocation of the blobs. For some reason, 'free' works just
    // fine, but '.deallocate' causes a crash.
    guard let objectBlob,
          let rootSignatureBlob else {
      fatalError("This should never happen.")
    }
    defer { free(objectBlob) }
    defer { free(rootSignatureBlob) }
    
    print("checkpoint 2")
    
    // Create the root signature.
    self.d3d12RootSignature =
    try! device.d3d12Device.CreateRootSignature(
      0, // nodeMask
      rootSignatureBlob, // pBlobWithRootSignature
      UInt64(rootSignatureLength)) // blobLengthInBytes
    
    print("checkpoint 3")
    
    // Fill the pipeline state descriptor.
    var pipelineStateDesc = D3D12_COMPUTE_PIPELINE_STATE_DESC()
    try! d3d12RootSignature.perform(
      as: WinSDK.ID3D12RootSignature.self
    ) { pUnk in
      pipelineStateDesc.pRootSignature = pUnk
    }
    pipelineStateDesc.CS.pShaderBytecode = UnsafeRawPointer(objectBlob)
    pipelineStateDesc.CS.BytecodeLength = UInt64(objectLength)
    
    print("checkpoint 4")
    
    // Create the pipeline state.
    self.d3d12PipelineState = try! device.d3d12Device
      .CreateComputePipelineState(pipelineStateDesc)
    
    print("checkpoint 5")
    #endif
  }
}

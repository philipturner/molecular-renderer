#if os(Windows)
import SwiftCOM
import WinSDK

import struct Foundation.Data

@_silgen_name("dxcompiler_compile")
private func dxcompiler_compile(
  _ source: UnsafePointer<CChar>,
  _ sourceLength: UInt32,
  _ object: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
  _ objectLength: UnsafeMutablePointer<UInt32>,
  _ rootSignature: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
  _ rootSignatureLength: UnsafeMutablePointer<UInt32>
) -> Int32

public struct ShaderDescriptor {
  public var device: Device?
  public var source: String?
  
  public init() {
    
  }
}

public struct Shader {
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
    
    // Check that the data pointers are not nil, and handle their deallocation.
    guard let objectBlob,
          let rootSignatureBlob else {
      fatalError("This should never happen.")
    }
    defer { objectBlob.deallocate() }
    defer { rootSignatureBlob.deallocate() }
    
    // Create the root signature.
    do {
      let d3d12Device = device.d3d12Device
      self.d3d12RootSignature =
      try! d3d12Device.CreateRootSignature(
        0, rootSignatureBlob, UInt64(rootSignatureLength))
    }
    
    // Fill the pipeline state descriptor.
    var pipelineStateDesc = D3D12_COMPUTE_PIPELINE_STATE_DESC()
    do  {
      // Set the 'pRootSignature' property.
      try! d3d12RootSignature.perform(
        as: WinSDK.ID3D12RootSignature.self
      ) { pUnk in
        pipelineStateDesc.pRootSignature = pUnk
      }
      
      // Set the 'CS' property.
      var shaderBytecode = D3D12_SHADER_BYTECODE()
      shaderBytecode.pShaderBytecode = UnsafeRawPointer(objectBlob)
      shaderBytecode.BytecodeLength = UInt64(objectLength)
      pipelineStateDesc.CS = shaderBytecode
    }
    
    // Create the pipeline state.
    do {
      let d3d12Device = device.d3d12Device
      var iid = SwiftCOM.ID3D12PipelineState.IID
      let pUnk = try! d3d12Device.CreateComputePipelineState(
        &pipelineStateDesc, &iid)
      self.d3d12PipelineState =
      SwiftCOM.ID3D12PipelineState(pUnk: pUnk)
    }
  }
}

#endif

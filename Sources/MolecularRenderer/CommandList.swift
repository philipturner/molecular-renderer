#if os(macOS)
import Metal
#else
import SwiftCOM
import WinSDK
#endif

public struct CommandList {
  #if os(macOS)
  public let mtlCommandEncoder: MTLComputeCommandEncoder
  #else
  public let d3d12CommandList: SwiftCOM.ID3D12GraphicsCommandList
  #endif
  
  public func setPipelineState(_ shader: Shader) {
    #if os(macOS)
    mtlCommandEncoder.setComputePipelineState(
      shader.mtlComputePipelineState)
    #else
    try! d3d12CommandList.SetPipelineState(
      shader.d3d12PipelineState)
    try! d3d12CommandList.SetComputeRootSignature(
      shader.d3d12RootSignature)
    #endif
  }
}

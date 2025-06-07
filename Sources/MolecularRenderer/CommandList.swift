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
  
  /// Binds the pipeline state object to the pipeline.
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
  
  /// Binds a UAV buffer to the pipeline.
  public func setBuffer(
    index: Int,
    buffer: Buffer,
    offset: Int = 0
  ) {
    #if os(macOS)
    mtlCommandEncoder.setBuffer(
      buffer.mtlBuffer, offset: offset, index: index)
    #else
    var gpuAddress = try! buffer.d3d12Resource.GetGPUVirtualAddress()
    gpuAddress += UInt64(offset)
    try! d3d12CommandList.SetComputeRootUnorderedAccessView(
      index, gpuAddress)
    #endif
  }
}

#if os(macOS)
import Metal
#else
import SwiftCOM
import WinSDK
#endif

public class CommandList {
  #if os(macOS)
  public let mtlCommandEncoder: MTLComputeCommandEncoder
  private var threadsPerGroup: MTLSize?
  #else
  public let d3d12CommandList: SwiftCOM.ID3D12GraphicsCommandList
  #endif
  
  #if os(macOS)
  init(mtlCommandEncoder: MTLComputeCommandEncoder) {
    self.mtlCommandEncoder = mtlCommandEncoder
  }
  #else
  init(d3d12CommandList: SwiftCOM.ID3D12GraphicsCommandList) {
    self.d3d12CommandList = d3d12CommandList
  }
  #endif
  
  /// Bind a pipeline state object.
  public func setPipelineState(_ shader: Shader) {
    #if os(macOS)
    mtlCommandEncoder.setComputePipelineState(
      shader.mtlComputePipelineState)
    threadsPerGroup = shader.threadsPerGroup
    #else
    try! d3d12CommandList.SetPipelineState(
      shader.d3d12PipelineState)
    try! d3d12CommandList.SetComputeRootSignature(
      shader.d3d12RootSignature)
    #endif
  }
  
  /// Bind a UAV buffer to the buffer table.
  public func setBuffer(
    _ buffer: Buffer,
    index: Int,
    offset: Int = 0
  ) {
    #if os(macOS)
    mtlCommandEncoder.setBuffer(
      buffer.mtlBuffer,
      offset: offset,
      index: index)
    #else
    var gpuAddress = try! buffer.d3d12Resource.GetGPUVirtualAddress()
    gpuAddress += UInt64(offset)
    
    try! d3d12CommandList.SetComputeRootUnorderedAccessView(
      UInt32(index),
      gpuAddress)
    #endif
  }
  
  /// Launch a kernel with the specified number of groups.
  public func dispatch(groups: SIMD3<UInt32>) {
    #if os(macOS)
    guard let threadsPerGroup else {
      fatalError("Forgot to set the pipeline state.")
    }
    
    var mtlSize = MTLSize()
    mtlSize.width = Int(groups[0])
    mtlSize.height = Int(groups[1])
    mtlSize.depth = Int(groups[2])
    
    mtlCommandEncoder.dispatchThreadgroups(
      mtlSize, // threadgroupsPerGrid
      threadsPerThreadgroup: threadsPerGroup)
    #else
    try! d3d12CommandList.Dispatch(
      groups[0], // ThreadGroupCountX
      groups[1], // ThreadGroupCountY
      groups[2]) // ThreadGroupCountZ
    #endif
  }
}

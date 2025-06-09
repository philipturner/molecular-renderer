#if os(macOS)
import Metal
#else
import SwiftCOM
import WinSDK
#endif

struct CommandListDescriptor {
  #if os(macOS)
  var mtlCommandBuffer: MTLCommandBuffer?
  #else
  var d3d12CommandList: SwiftCOM.ID3D12GraphicsCommandList?
  var fenceValue: UInt64?
}

public class CommandList {
  #if os(macOS)
  internal let mtlCommandBuffer: MTLCommandBuffer
  
  public let mtlCommandEncoder: MTLComputeCommandEncoder
  
  private var threadsPerGroup: MTLSize?
  #else
  public let d3d12CommandList: SwiftCOM.ID3D12GraphicsCommandList
  
  // The fence value in the command queue that created this.
  internal let fenceValue: UInt64
  #endif
  
  init(descriptor: CommandListDescriptor) {
    #if os(macOS)
    guard let mtlCommandBuffer = descriptor.mtlCommandBuffer else {
      fatalError("Descriptor was incomplete.")
    }
    #else
    guard let d3d12CommandList = descriptor.d3d12CommandList,
          let fenceValue = descriptor.fenceValue else {
      fatalError("Descriptor was incomplete.")
    }
    #endif
    
    #if os(macOS)
    self.mtlCommandBuffer = mtlCommandBuffer
    self.mtlCommandEncoder = mtlCommandBuffer.makeComputeCommandEncoder()!
    #else
    self.d3d12CommandList = d3d12CommandList
    self.fenceValue = fenceValue
    #endif
  }
  
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

extension CommandList {
  #if os(Windows)
  public func upload(
    inputBuffer: Buffer,
    nativeBuffer: Buffer
  ) {
    // Verify the state of the input buffer.
    guard inputBuffer.state == BufferType.input.initialState else {
      fatalError("Input buffer had an unexpected state.")
    }
    
    // Set the state of the native buffer.
    let desiredNativeState = D3D12_RESOURCE_STATE_COPY_DEST
    if nativeBuffer.state != desiredNativeState {
      let barrier = nativeBuffer.transition(state: desiredNativeState)
      try! d3d12CommandList.ResourceBarrier(1, [barrier])
    }
    
    // Encode the copy command.
    try! d3d12CommandList.CopyResource(
      nativeBuffer.d3d12Resource, // pDstResource
      inputBuffer.d3d12Resource) // pSrcResource
  }
  
  public func download(
    nativeBuffer: Buffer,
    outputBuffer: Buffer
  ) {
    // Verify the state of the output buffer.
    guard outputBuffer.state == BufferType.output.initialState else {
      fatalError("Output buffer had an unexpected state.")
    }
    
    // Set the state of the native buffer.
    let desiredNativeState = D3D12_RESOURCE_STATE_COPY_SOURCE
    if nativeBuffer.state != desiredNativeState {
      let barrier = nativeBuffer.transition(state: desiredNativeState)
      try! d3d12CommandList.ResourceBarrier(1, [barrier])
    }
    
    // Encode the copy command.
    try! d3d12CommandList.CopyResource(
      outputBuffer.d3d12Resource, // pDstResource
      nativeBuffer.d3d12Resource) // pSrcResource
  }
  #endif
}

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
  var commandSignature: SwiftCOM.ID3D12CommandSignature?
  var d3d12CommandList: SwiftCOM.ID3D12GraphicsCommandList?
  var fenceValue: UInt64?
  #endif
}

class CommandList {
  #if os(macOS)
  let mtlCommandBuffer: MTLCommandBuffer
  
  var mtlCommandEncoder: MTLComputeCommandEncoder
  #else
  let commandSignature: SwiftCOM.ID3D12CommandSignature
  let d3d12CommandList: SwiftCOM.ID3D12GraphicsCommandList
  
  // The fence value in the command queue that created this.
  let fenceValue: UInt64
  #endif
  
  // Internally tracked pipeline state, necessary for dispatching threads.
  private var shader: Shader?
  
  #if os(Windows)
  // Internally tracked descriptor heap.
  var descriptorHeap: DescriptorHeap?
  #endif
  
  init(descriptor: CommandListDescriptor) {
    #if os(macOS)
    guard let mtlCommandBuffer = descriptor.mtlCommandBuffer else {
      fatalError("Descriptor was incomplete.")
    }
    #else
    guard let commandSignature = descriptor.commandSignature,
          let d3d12CommandList = descriptor.d3d12CommandList,
          let fenceValue = descriptor.fenceValue else {
      fatalError("Descriptor was incomplete.")
    }
    #endif
    
    #if os(macOS)
    self.mtlCommandBuffer = mtlCommandBuffer
    self.mtlCommandEncoder = mtlCommandBuffer.makeComputeCommandEncoder()!
    #else
    self.commandSignature = commandSignature
    self.d3d12CommandList = d3d12CommandList
    self.fenceValue = fenceValue
    #endif
  }
}

// MARK: - Compute Commands

extension CommandList {
  func withPipelineState(
    _ shader: Shader,
    _ closure: () -> Void
  ) {
    guard self.shader == nil else {
      fatalError(
        "Cannot start a new command in the middle of a previous command.")
    }
    
    #if os(macOS)
    mtlCommandEncoder.setComputePipelineState(
      shader.mtlComputePipelineState)
    #else
    try! d3d12CommandList.SetPipelineState(
      shader.d3d12PipelineState)
    try! d3d12CommandList.SetComputeRootSignature(
      shader.d3d12RootSignature)
    #endif
    
    self.shader = shader
    closure()
    self.shader = nil
  }
  
  func set32BitConstants<T>(
    _ constants: T,
    index: Int
  ) {
    // Compute the byte count based on the size, not the stride.
    let byteCount = MemoryLayout<T>.size
    guard byteCount % 4 == 0 else {
      fatalError("Could not determine number of 32-bit constants.")
    }
    
    withUnsafePointer(to: constants) { pConstants in
      #if os(macOS)
      mtlCommandEncoder.setBytes(
        pConstants,
        length: byteCount,
        index: index)
      #else
      try! d3d12CommandList.SetComputeRoot32BitConstants(
        UInt32(index), // RootParameterIndex
        UInt32(byteCount / 4), // Num32BitValuesToSet
        pConstants, // pSrcData
        0) // DestOffsetIn32BitValues
      #endif
    }
  }
  
  /// Bind a CBV/UAV buffer to the buffer table.
  func setBuffer(
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
    
    switch buffer.type {
    case .native(.constant):
      try! d3d12CommandList.SetComputeRootConstantBufferView(
        UInt32(index), // RootParameterIndex
        gpuAddress) // BufferLocation
    case .native(.device):
      try! d3d12CommandList.SetComputeRootUnorderedAccessView(
        UInt32(index), // RootParameterIndex
        gpuAddress) // BufferLocation
    default:
      fatalError("This should never happen.")
    }
    
    
    #endif
  }
  
  /// Launch a kernel with the specified number of groups.
  func dispatch(groups: SIMD3<UInt32>) {
    #if os(macOS)
    guard let shader else {
      fatalError("Pipeline state was not set.")
    }
    #else
    guard shader != nil else {
      fatalError("Pipeline state was not set.")
    }
    #endif
    
    #if os(macOS)
    var mtlSize = MTLSize()
    mtlSize.width = Int(groups[0])
    mtlSize.height = Int(groups[1])
    mtlSize.depth = Int(groups[2])
    
    mtlCommandEncoder.dispatchThreadgroups(
      mtlSize, // threadgroupsPerGrid
      threadsPerThreadgroup: shader.threadsPerGroup)
    #else
    try! d3d12CommandList.Dispatch(
      groups[0], // ThreadGroupCountX
      groups[1], // ThreadGroupCountY
      groups[2]) // ThreadGroupCountZ
    #endif
  }
  
  /// Launch a kernel via indirect dispatch.
  ///
  /// WARNING: The buffer used for indirect arguments must not be bound to
  /// the buffer table.
  func dispatchIndirect(
    buffer: Buffer,
    offset: Int = 0
  ) {
    #if os(macOS)
    guard let shader else {
      fatalError("Pipeline state was not set.")
    }
    #else
    guard shader != nil else {
      fatalError("Pipeline state was not set.")
    }
    #endif
    
    #if os(macOS)
    mtlCommandEncoder.dispatchThreadgroups(
      indirectBuffer: buffer.mtlBuffer,
      indirectBufferOffset: offset,
      threadsPerThreadgroup: shader.threadsPerGroup)
    #else
    let desiredState = D3D12_RESOURCE_STATE_INDIRECT_ARGUMENT
    let originalState = buffer.state
    if originalState != desiredState {
      let barrier = buffer.transition(state: desiredState)
      try! d3d12CommandList.ResourceBarrier(1, [barrier])
    }
    
    try! d3d12CommandList.ExecuteIndirect(
      commandSignature, // pCommandSignature
      UInt32(1), // MaxCommandCount
      buffer.d3d12Resource, // pArgumentBuffer
      UInt64(offset), // ArgumentBufferOffset
      nil, // pCountBuffer
      UInt64(0)) // CountBufferOffset
    
    if originalState != desiredState {
      let barrier = buffer.transition(state: originalState)
      try! d3d12CommandList.ResourceBarrier(1, [barrier])
    }
    #endif
  }
}

// MARK: - Copy Commands

#if os(Windows)
extension CommandList {
  func upload(
    inputBuffer: Buffer,
    nativeBuffer: Buffer,
    range: Range<Int>? = nil
  ) {
    guard shader == nil else {
      fatalError(
        "Cannot encode copy commands in the middle of a compute command.")
    }
    
    // Verify the state of the input buffer.
    guard inputBuffer.state == BufferType.input.initialState else {
      fatalError("Input buffer had an unexpected state.")
    }
    
    // Set the state of the native buffer.
    let desiredNativeState = D3D12_RESOURCE_STATE_COPY_DEST
    if nativeBuffer.state != desiredNativeState {
      fatalError("Native buffer must be in COPY_DEST state")
      let barrier = nativeBuffer.transition(state: desiredNativeState)
      try! d3d12CommandList.ResourceBarrier(1, [barrier])
    }
    
    // Encode the copy command.
    if let range {
      try! d3d12CommandList.CopyBufferRegion(
        nativeBuffer.d3d12Resource, // pDstBuffer
        UInt64(range.startIndex), // DstOffset
        inputBuffer.d3d12Resource, // pSrcBuffer
        UInt64(range.startIndex), // SrcOffset
        UInt64(range.count))
    } else {
      try! d3d12CommandList.CopyResource(
        nativeBuffer.d3d12Resource, // pDstResource
        inputBuffer.d3d12Resource) // pSrcResource
    }
  }
  
  func download(
    nativeBuffer: Buffer,
    outputBuffer: Buffer,
    range: Range<Int>? = nil
  ) {
    guard shader == nil else {
      fatalError(
        "Cannot encode copy commands in the middle of a compute command.")
    }
    
    // Verify the state of the output buffer.
    guard outputBuffer.state == BufferType.output.initialState else {
      fatalError("Output buffer had an unexpected state.")
    }
    
    // Set the state of the native buffer.
    let desiredNativeState = D3D12_RESOURCE_STATE_COPY_SOURCE
    if nativeBuffer.state != desiredNativeState {
      fatalError("Native buffer must be in COPY_SOURCE state")
      let barrier = nativeBuffer.transition(state: desiredNativeState)
      try! d3d12CommandList.ResourceBarrier(1, [barrier])
    }
    
    // Encode the copy command.
    if let range {
      try! d3d12CommandList.CopyBufferRegion(
        outputBuffer.d3d12Resource, // pDstBuffer
        UInt64(range.startIndex), // DstOffset
        nativeBuffer.d3d12Resource, // pSrcBuffer
        UInt64(range.startIndex), // SrcOffset
        UInt64(range.count))
    } else {
      try! d3d12CommandList.CopyResource(
        outputBuffer.d3d12Resource, // pDstResource
        nativeBuffer.d3d12Resource) // pSrcResource
    }
  }
}
#endif

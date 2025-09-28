#if os(Windows)
import SwiftCOM
import WinSDK
#endif

public struct RingBuffer {
  #if os(Windows)
  public var inputBuffers: [Buffer] = []
  #endif
  public var nativeBuffers: [Buffer] = []
  
  public init(
    device: Device,
    byteCount: Int
  ) {
    for _ in 0..<3 {
      var bufferDesc = BufferDescriptor()
      bufferDesc.device = device
      bufferDesc.size = byteCount
      
      #if os(Windows)
      bufferDesc.type = .input
      let inputBuffer = Buffer(descriptor: bufferDesc)
      inputBuffers.append(inputBuffer)
      #endif
      
      bufferDesc.type = .native
      let nativeBuffer = Buffer(descriptor: bufferDesc)
      nativeBuffers.append(nativeBuffer)
    }
  }
  
  public mutating func write<T>(
    data: [T],
    inFlightFrameID: Int
  ) {
    data.withUnsafeBytes { bufferPointer in
      let baseAddress = bufferPointer.baseAddress!
      
      #if os(macOS)
      let buffer = nativeBuffers[inFlightFrameID]
      #else
      let buffer = inputBuffers[inFlightFrameID]
      #endif
      buffer.write(input: baseAddress)
    }
  }
  
  #if os(Windows)
  public func copy(
    commandList: CommandList,
    inFlightFrameID: Int
  ) {
    let inputBuffer = inputBuffers[inFlightFrameID]
    let nativeBuffer = nativeBuffers[inFlightFrameID]
    
    let copyDestBarrier = nativeBuffer
      .transition(state: D3D12_RESOURCE_STATE_COPY_DEST)
    try! commandList.d3d12CommandList.ResourceBarrier(
      1, [copyDestBarrier])
    
    commandList.upload(
      inputBuffer: inputBuffer,
      nativeBuffer: nativeBuffer)
    
    let unorderedAccessBarrier = nativeBuffer
      .transition(state: D3D12_RESOURCE_STATE_UNORDERED_ACCESS)
    try! commandList.d3d12CommandList.ResourceBarrier(
      1, [unorderedAccessBarrier])
  }
  #endif
}

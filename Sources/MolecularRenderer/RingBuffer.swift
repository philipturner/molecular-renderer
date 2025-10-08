#if os(Windows)
import SwiftCOM
import WinSDK
#endif

struct RingBufferDescriptor {
  var accessLevel: BufferAccessLevel?
  var device: Device?
  var size: Int?
}

struct RingBuffer {
  #if os(Windows)
  var inputBuffers: [Buffer] = []
  #endif
  var nativeBuffers: [Buffer] = []
  
  init(descriptor: RingBufferDescriptor) {
    guard let accessLevel = descriptor.accessLevel,
          let device = descriptor.device,
          let size = descriptor.size else {
      fatalError("Descriptor was incomplete.")
    }
    
    for _ in 0..<3 {
      var bufferDesc = BufferDescriptor()
      bufferDesc.device = device
      bufferDesc.size = size
      
      #if os(Windows)
      bufferDesc.type = .input
      let inputBuffer = Buffer(descriptor: bufferDesc)
      inputBuffers.append(inputBuffer)
      #endif
      
      bufferDesc.type = .native(accessLevel)
      let nativeBuffer = Buffer(descriptor: bufferDesc)
      nativeBuffers.append(nativeBuffer)
    }
  }
  
  mutating func write<T>(
    data: [T],
    inFlightFrameID: Int
  ) {
    data.withUnsafeBytes { bufferPointer in
      #if os(macOS)
      let buffer = nativeBuffers[inFlightFrameID]
      #else
      let buffer = inputBuffers[inFlightFrameID]
      #endif
      buffer.write(input: bufferPointer)
    }
  }
  
  #if os(Windows)
  func copy(
    commandList: CommandList,
    inFlightFrameID: Int,
    range: Range<Int>? = nil
  ) {
    let inputBuffer = inputBuffers[inFlightFrameID]
    let nativeBuffer = nativeBuffers[inFlightFrameID]
    
    let copyDestBarrier = nativeBuffer
      .transition(state: D3D12_RESOURCE_STATE_COPY_DEST)
    try! commandList.d3d12CommandList.ResourceBarrier(
      1, [copyDestBarrier])
    
    commandList.upload(
      inputBuffer: inputBuffer,
      nativeBuffer: nativeBuffer,
      range: range)
    
    func createState() -> D3D12_RESOURCE_STATES {
      switch nativeBuffer.type {
      case .native(.constant):
        return D3D12_RESOURCE_STATE_VERTEX_AND_CONSTANT_BUFFER
      case .native(.device):
        return D3D12_RESOURCE_STATE_UNORDERED_ACCESS
      default:
        fatalError("This should never happen.")
      }
    }
    let unorderedAccessBarrier = nativeBuffer
      .transition(state: createState())
    try! commandList.d3d12CommandList.ResourceBarrier(
      1, [unorderedAccessBarrier])
  }
  #endif
}

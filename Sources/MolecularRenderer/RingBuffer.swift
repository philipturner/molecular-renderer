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
  
  // TODO: Delete this utility entirely.
  #if os(Windows)
  func copy(
    commandList: CommandList,
    inFlightFrameID: Int,
    range: Range<Int>? = nil
  ) {
    let inputBuffer = inputBuffers[inFlightFrameID]
    let nativeBuffer = nativeBuffers[inFlightFrameID]
    
    commandList.upload(
      inputBuffer: inputBuffer,
      nativeBuffer: nativeBuffer,
      range: range)
  }
  #endif
}

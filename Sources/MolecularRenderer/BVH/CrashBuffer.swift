#if os(macOS)
import Metal
#else
import SwiftCOM
import WinSDK
#endif

// CPU initializes data to zero on startup
// - 1 upload buffer
// used in every GPU command
// - 1 native buffer
// GPU data downloaded to CPU
// - 3 download buffers
// - Do NOT read their data during the first 3 frames!
// - Zero indicates an error, since it's the default value that would be
//   read incorrectly during the first 3 frames. Instead, 1 means nothing
//   went wrong.
struct CrashBufferDescriptor {
  var device: Device?
  
  // Size in bytes, not number of UInt32 elements.
  var size: Int?
}

class CrashBuffer {
  let inputBuffer: Buffer
  let nativeBuffer: Buffer
  var outputBuffers: [Buffer] = []
  
  init(descriptor: CrashBufferDescriptor) {
    guard let device = descriptor.device,
          let size = descriptor.size else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Create the input buffer.
    do {
      var bufferDesc = BufferDescriptor()
      bufferDesc.device = device
      bufferDesc.size = size
      #if os(macOS)
      bufferDesc.type = .native(.device)
      #else
      bufferDesc.type = .input
      #endif
      self.inputBuffer = Buffer(descriptor: bufferDesc)
    }
    
    // Create the native buffer.
    do {
      var bufferDesc = BufferDescriptor()
      bufferDesc.device = device
      bufferDesc.size = size
      bufferDesc.type = .native(.device)
      self.nativeBuffer = Buffer(descriptor: bufferDesc)
    }
    
    // Create the output buffers.
    for _ in 0..<3 {
      var bufferDesc = BufferDescriptor()
      bufferDesc.device = device
      bufferDesc.size = size
      #if os(macOS)
      bufferDesc.type = .native(.device)
      #else
      bufferDesc.type = .output
      #endif
      let outputBuffer = Buffer(descriptor: bufferDesc)
      outputBuffers.append(outputBuffer)
    }
  }
  
  func initialize(
    commandList: CommandList,
    data: [UInt32]
  ) {
    data.withUnsafeBytes { bufferPointer in
      let buffer = inputBuffer
      buffer.write(input: bufferPointer)
    }
    
    #if os(macOS)
    commandList.mtlCommandEncoder.endEncoding()
    
    let commandEncoder: MTLBlitCommandEncoder =
    commandList.mtlCommandBuffer.makeBlitCommandEncoder()!
    commandEncoder.copy(
      from: inputBuffer.mtlBuffer, sourceOffset: 0,
      to: nativeBuffer.mtlBuffer, destinationOffset: 0,
      size: inputBuffer.size)
    commandEncoder.endEncoding()
    
    commandList.mtlCommandEncoder =
    commandList.mtlCommandBuffer.makeComputeCommandEncoder()!
    #else
    commandList.upload(
      inputBuffer: inputBuffer,
      nativeBuffer: nativeBuffer)
    #endif
  }
  
  func download(
    commandList: CommandList,
    inFlightFrameID: Int
  ) {
    let outputBuffer = outputBuffers[inFlightFrameID]
    
    #if os(macOS)
    commandList.mtlCommandEncoder.endEncoding()
    
    let commandEncoder: MTLBlitCommandEncoder =
    commandList.mtlCommandBuffer.makeBlitCommandEncoder()!
    commandEncoder.copy(
      from: nativeBuffer.mtlBuffer, sourceOffset: 0,
      to: outputBuffer.mtlBuffer, destinationOffset: 0,
      size: nativeBuffer.size)
    commandEncoder.endEncoding()
    
    commandList.mtlCommandEncoder =
    commandList.mtlCommandBuffer.makeComputeCommandEncoder()!
    #else
    commandList.download(
      nativeBuffer: nativeBuffer,
      outputBuffer: outputBuffer)
    #endif
  }
  
  func read<T>(
    data: inout [T],
    inFlightFrameID: Int
  ) {
    data.withUnsafeMutableBytes { bufferPointer in
      let buffer = outputBuffers[inFlightFrameID]
      buffer.read(output: bufferPointer)
    }
  }
}

extension CrashBuffer {
  static var functionArguments: String {
    #if os(macOS)
    "device uint *crashBuffer [[buffer(0)]]"
    #else
    "RWStructuredBuffer<uint> crashBuffer : register(u0);"
    #endif
  }
  
  #if os(Windows)
  static var rootSignatureArguments: String {
    """
    "UAV(u0),"
    """
  }
  #endif
  
  func setBufferBindings(
    commandList: CommandList
  ) {
    commandList.setBuffer(nativeBuffer, index: 0)
  }
  
  // Declare 'bool acquiredLock = false;' prior to invoking this.
  static func acquireLock(errorCode: Int) -> String {
    #if os(macOS)
    """
    {
      uint expected = 1;
      acquiredLock = atomic_compare_exchange_weak_explicit(
        (device atomic_uint*)crashBuffer, // object
        &expected, // expected
        \(errorCode), // desired
        memory_order_relaxed, // success
        memory_order_relaxed); // failure
    }
    """
    #else
    """
    {
      uint output;
      InterlockedCompareExchange(
        crashBuffer[0], // dest
        1, // compare_value
        \(errorCode), // value
        output); // original_value
      if (output == 1) {
        acquiredLock = true;
      }
    }
    """
    #endif
  }
}

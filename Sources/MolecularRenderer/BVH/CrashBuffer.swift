#if os(Windows)
import SwiftCOM
import WinSDK
#endif

// CPU initializes data to zero on startup
// - 1 upload buffer
// used in every GPU command
// - 1 native buffer
// GPU data downloaded to CPU
// - 3 download buffers
// - do NOT read their data during the first 3 frames!
// - make one exception for the early stages of code testing, where the
//   download command is invoked in a unique place, and the command queue
//   is flushed
//
// This could be used to easily gather diagnostic data while taking the first
// steps to test & debug BVH building.
struct CrashBufferDescriptor {
  var device: Device?
  var size: Int?
}

struct CrashBuffer {
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
  
  // func initialize(data: [UInt32])
}

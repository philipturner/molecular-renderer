import MolecularRenderer

struct AtomBuffer {
  #if os(Windows)
  var inputBuffers: [Buffer] = []
  #endif
  var nativeBuffers: [Buffer] = []
  
  init(
    device: Device,
    atomCount: Int
  ) {
    for _ in 0..<3 {
      var bufferDesc = BufferDescriptor()
      bufferDesc.device = device
      bufferDesc.size = atomCount * 16
      
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
  
  mutating func write(
    atoms: [SIMD4<Float>],
    inFlightFrameID: Int
  ) {
    
  }
}

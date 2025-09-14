import MolecularRenderer

struct AtomBuffer {
  var inputBuffers: [Buffer] = []
  var nativeBuffers: [Buffer] = []
  
  init(
    device: Device,
    atomCount: Int
  ) {
    for _ in 0..<3 {
      var bufferDesc = BufferDescriptor()
    }
  }
}

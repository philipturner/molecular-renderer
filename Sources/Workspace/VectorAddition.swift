#if os(Windows)
import MolecularRenderer

/// Utility code for setting up a vector addition test.
class VectorAddition {
  let inputBuffer0: Buffer
  let inputBuffer1: Buffer
  
  let nativeBuffer0: Buffer
  let nativeBuffer1: Buffer
  let nativeBuffer2: Buffer
  
  let outputBuffer2: Buffer
  
  init(device: Device) {
    // Fill the descriptor properties common to all buffers.
    var bufferDesc = BufferDescriptor()
    bufferDesc.device = device
    bufferDesc.size = 1024 * 4

    // Create the input buffers.
    bufferDesc.type = .input
    self.inputBuffer0 = Buffer(descriptor: bufferDesc)
    self.inputBuffer1 = Buffer(descriptor: bufferDesc)

    // Create the native buffers.
    bufferDesc.type = .native
    self.nativeBuffer0 = Buffer(descriptor: bufferDesc)
    self.nativeBuffer1 = Buffer(descriptor: bufferDesc)
    self.nativeBuffer2 = Buffer(descriptor: bufferDesc)

    // Create the output buffers.
    bufferDesc.type = .output
    self.outputBuffer2 = Buffer(descriptor: bufferDesc)
    
    // Generate the input data for the shader.
    var inputData0: [Float] = []
    var inputData1: [Float] = []
    for i in 0..<1024 {
      let value0 = Float(i)
      let value1 = 1024 + Float(i)
      inputData0.append(value0)
      inputData1.append(value1)
    }
    
    inputData0.withUnsafeBytes { bufferPointer in
      let baseAddress = bufferPointer.baseAddress!
      inputBuffer0.write(input: baseAddress)
    }
    
    inputData1.withUnsafeBytes { bufferPointer in
      let baseAddress = bufferPointer.baseAddress!
      inputBuffer1.write(input: baseAddress)
    }
  }
}

#endif

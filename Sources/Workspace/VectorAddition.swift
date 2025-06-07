import MolecularRenderer

/// Utility code for setting up a vector addition test.
class VectorAddition {
  #if os(Windows)
  let inputBuffer0: Buffer
  let inputBuffer1: Buffer
  #endif
  
  let nativeBuffer0: Buffer
  let nativeBuffer1: Buffer
  let nativeBuffer2: Buffer
  
  #if os(Windows)
  let outputBuffer2: Buffer
  #endif
  
  init(device: Device) {
    // Fill the descriptor properties common to all buffers.
    var bufferDesc = BufferDescriptor()
    bufferDesc.device = device
    bufferDesc.size = 1024 * 4
    
    // Create the input buffers.
    #if os(Windows)
    bufferDesc.type = .input
    self.inputBuffer0 = Buffer(descriptor: bufferDesc)
    self.inputBuffer1 = Buffer(descriptor: bufferDesc)
    #endif
    
    // Create the native buffers.
    bufferDesc.type = .native
    self.nativeBuffer0 = Buffer(descriptor: bufferDesc)
    self.nativeBuffer1 = Buffer(descriptor: bufferDesc)
    self.nativeBuffer2 = Buffer(descriptor: bufferDesc)
    
    // Create the output buffers.
    #if os(Windows)
    bufferDesc.type = .output
    self.outputBuffer2 = Buffer(descriptor: bufferDesc)
    #endif
    
    // Generate the input data for the shader.
    var inputData0: [Float] = []
    var inputData1: [Float] = []
    for i in 0..<1024 {
      let value0 = Float(i)
      let value1 = 1024 + Float(i)
      inputData0.append(value0)
      inputData1.append(value1)
    }
    
    // Write the contents of buffer 0.
    inputData0.withUnsafeBytes { bufferPointer in
      let baseAddress = bufferPointer.baseAddress!
      #if os(macOS)
      nativeBuffer0.write(input: baseAddress)
      #else
      inputBuffer0.write(input: baseAddress)
      #endif
    }
    
    // Write the contents of buffer 1.
    inputData1.withUnsafeBytes { bufferPointer in
      let baseAddress = bufferPointer.baseAddress!
      #if os(macOS)
      nativeBuffer1.write(input: baseAddress)
      #else
      inputBuffer1.write(input: baseAddress)
      #endif
    }
  }
  
  // Read the contents of buffer 2.
  var results: [Float] {
    var output = [Float](repeating: 0, count: 1024)
    output.withUnsafeMutableBytes { bufferPointer in
      let baseAddress = bufferPointer.baseAddress!
      #if os(macOS)
      nativeBuffer2.read(output: baseAddress)
      #else
      outputBuffer2.read(output: baseAddress)
      #endif
    }
    return output
  }
}

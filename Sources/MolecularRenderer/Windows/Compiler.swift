#if os(Windows)
import SwiftCOM
import WinSDK

import struct Foundation.Data

@_silgen_name("dxcompiler_compile")
private func dxcompiler_compile(
  _ source: UnsafePointer<CChar>,
  _ sourceLength: UInt32,
  _ object: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
  _ objectLength: UnsafeMutablePointer<UInt32>,
  _ rootSignature: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
  _ rootSignatureLength: UnsafeMutablePointer<UInt32>
) -> Int32

public class Compiler {
  private let device: DirectXDevice
  
  public init(device: DirectXDevice) {
    self.device = device
  }
  
  public func compile(source: String) -> ShaderBytecode {
    // Declare the function arguments and return values.
    let sourceCount = UInt32(source.count)
    var object: UnsafeMutablePointer<UInt8>?
    var objectLength: UInt32 = .zero
    var rootSignature: UnsafeMutablePointer<UInt8>?
    var rootSignatureLength: UInt32 = .zero
    
    // Invoke the function from the DXC wrapper.
    let errorCode = dxcompiler_compile(
      source,
      sourceCount,
      &object,
      &objectLength,
      &rootSignature,
      &rootSignatureLength)
    if errorCode != 0 {
      fatalError("dxcompiler_compile failed with error code \(errorCode).")
    }
    
    // Create the shader bytecode struct.
    guard let object,
          let rootSignature else {
      fatalError("This should never happen.")
    }
    
    var shaderBytecode: ShaderBytecode
    do {
      let objectData = Data(
        bytesNoCopy: object,
        count: Int(objectLength),
        deallocator: .free)
      let rootSignatureData = Data(
        bytesNoCopy: rootSignature,
        count: Int(rootSignatureLength),
        deallocator: .free)
      
      shaderBytecode = ShaderBytecode(
        object: objectData,
        rootSignature: rootSignatureData)
    }
    
    return shaderBytecode
  }
}

// TODO: Change ShaderBytecode to ShaderDescriptor, but make the descriptor
// and the Shader initializer internal. Change 'Compiler' to just
// 'DirectXDevice', and put 'compile' in an 'extension'. Keep all of that, as
// well as the 'dxcompiler_compile' reference, in the same file as 'Shader'.
//
// And finally, change DirectXDevice to just Device. This brings it closer to
// merging with the Metal backend in the future.

// Unsure whether DXIL is a bitcode or a bytecode.
public struct ShaderBytecode {
  public let object: Data
  public let rootSignature: Data
  
  // Use the internal initializer (auto-generated) for now.
}

#endif

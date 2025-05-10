#if os(Windows)
import SwiftCOM
import WinSDK

@_silgen_name("dxcompiler_compile")
private func dxcompiler_compile(
  _ shaderSource: UnsafePointer<CChar>,
  _ shaderSourceLength: UInt32
) -> UInt8

public class Compiler {
  private var device: DirectXDevice
  
  public init(device: DirectXDevice) {
    self.device = device
  }
  
  public func compile(source: String) -> ShaderBytecode {
    let sourceCount = UInt32(source.count)
    var object: UnsafeMutablePointer<UInt8>?
    var objectLength: UInt32 = .zero
    var rootSignature: UnsafeMutablePointer<UInt8>?
    var rootSignatureLength: UInt32 = .zero
    
    
    
    let errorCode = dxcompiler_compile(
      source,
      sourceCount)
    if errorCode != 0 {
      fatalError("dxcompiler_compile failed with error code \(errorCode).")
    }
    
    // Create the shader bytecode struct.
    guard let object,
          let rootSignature else {
      fatalError("This should never happen.")
    }
    
    fatalError("Not implemented.")
  }
}

// Unsure whether DXIL is a bitcode or a bytecode.
public struct ShaderBytecode {
  public let object: Data
  public let rootSignature: Data
  
  // Use the internal initializer (auto-generated) for now.
}

#endif

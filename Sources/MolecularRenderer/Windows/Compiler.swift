#if os(Windows)
import SwiftCOM
import WinSDK

@_silgen_name("dxcompiler_compile")
private func dxcompiler_compile(
  _ shaderSource: UnsafePointer<CChar>,
  _ shaderSourceLength: UInt32
) -> Int8

public struct CompilerDescriptor {
  public var device: SwiftCOM.ID3D12Device?
  
  public init() {
    
  }
}

public class Compiler {
  public init(device: SwiftCOM.ID3D12Device) {
    
  }
  
  public func compile(source: String) -> Int8 {
    let sourceCount = UInt32(source.count)
    let result = dxcompiler_compile(source, source.count)
    return result
  }
}

#endif

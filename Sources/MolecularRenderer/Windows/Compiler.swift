#if os(Windows)
import SwiftCOM
import WinSDK

@_silgen_name("dxcompiler_compile")
private func dxcompiler_compile(
  _ shaderSource: UnsafePointer<CChar>,
  _ shaderSourceLength: UInt32
) -> Int8

public struct Compiler {
  private var device: DirectXDevice
  
  public init(device: DirectXDevice) {
    self.device = device
  }
  
  public func compile(source: String) -> Int8 {
    let sourceCount = UInt32(source.count)
    let result = dxcompiler_compile(source, sourceCount)
    return result
  }
}

#endif

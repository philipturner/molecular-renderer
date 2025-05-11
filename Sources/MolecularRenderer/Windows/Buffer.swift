#if os(Windows)
import SwiftCOM
import WinSDK

public struct BufferDescriptor {
  public var device: DirectXDevice?
  public var size: Int = .zero
  public var type: BufferType?
  
  public init() {
    
  }
}

public enum BufferType {
  // CPU can write, GPU memory accesses are slow.
  case input
  
  // GPU memory accesses are fast.
  case native
  
  // CPU can read, GPU memory accesses are slow.
  case output
}

public class Buffer {
  public init(descriptor: BufferDescriptor) {
    
  }
}

#endif

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
  
  var heapType: D3D12_HEAP_TYPE {
    switch self {
    case .input:
      return D3D12_HEAP_TYPE_UPLOAD
    case .native:
      return D3D12_HEAP_TYPE_DEFAULT
    case .output:
      return D3D12_HEAP_TYPE_READBACK
    }
  }
  
  public var resourceStates: D3D12_RESOURCE_STATES {
    // Declare the unique state.
    var uniqueState: D3D12_RESOURCE_STATES
    
    // Select the unique state.
    switch self {
    case .input:
      uniqueState = D3D12_RESOURCE_STATE_GENERIC_READ // 2755
    case .native:
      uniqueState = D3D12_RESOURCE_STATE_COMMON // 0
    case .output:
      uniqueState = D3D12_RESOURCE_STATE_COPY_DEST // 1024
    }
    
    // Declare the common state.
    let commonState = D3D12_RESOURCE_STATE_UNORDERED_ACCESS // 8
    
    // Merge the raw values.
    var rawValue: Int32 = .zero
    rawValue |= uniqueState.rawValue
    rawValue |= commonState.rawValue
    
    // Return a combined set of states.
    let output = D3D12_RESOURCE_STATES(rawValue: rawValue)
    return output
  }
}

public class Buffer {
  public init(descriptor: BufferDescriptor) {
    
  }
}

#endif

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
  
  var resourceStates: D3D12_RESOURCE_STATES {
    // Declare the unique state.
    var uniqueState: D3D12_RESOURCE_STATES
    
    // Select the unique state.
    switch self {
    case .input:
      uniqueState = D3D12_RESOURCE_STATE_GENERIC_READ
    case .native:
      uniqueState = D3D12_RESOURCE_STATE_COMMON
    case .output:
      uniqueState = D3D12_RESOURCE_STATE_COPY_DEST
    }
    
    // Declare the common state.
    let commonState = D3D12_RESOURCE_STATE_UNORDERED_ACCESS
    
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
  // public let resource
  
  public let size: Int
  public let type: BufferType
  
  public init(descriptor: BufferDescriptor) {
    guard let device = descriptor.device,
          let type = descriptor.type else {
      fatalError("Descriptor was incomplete.")
    }
    self.type = type
    
    // Check that the size is valid.
    guard descriptor.size > 0 else {
      fatalError("Buffer size must be nonzero.")
    }
    self.size = descriptor.size
    
    // Fill the heap descriptor.
    var heapProperties = D3D12_HEAP_PROPERTIES()
    heapProperties.Type = type.heapType
    heapProperties.CPUPageProperty = D3D12_CPU_PAGE_PROPERTY_UNKNOWN
    heapProperties.MemoryPoolPreference = D3D12_MEMORY_POOL_UNKNOWN
    heapProperties.CreationNodeMask = 0
    heapProperties.VisibleNodeMask = 0
    
    // Fill the resource descriptor.
    var resourceDesc = D3D12_RESOURCE_DESC()
    resourceDesc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER
    resourceDesc.Alignment = 0
    resourceDesc.Width = UINT64(size)
    resourceDesc.Height = 1
    resourceDesc.DepthOrArraySize = 1
    resourceDesc.MipLevels = 1
    resourceDesc.Format = DXGI_FORMAT_UNKNOWN
    resourceDesc.SampleDesc = DXGI_SAMPLE_DESC(Count: 1, Quality: 0)
    resourceDesc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR
    resourceDesc.Flags = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS
    
    // Retrieve the resource states.
    let resourceStates = type.resourceStates
    
    
  }
}

#endif

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

// How to get data on/off the GPU:
//
// input buffer:
// - always in state GENERIC_READ
// - resource flags NONE
//
// native buffer:
// - state can vary based on the operation
//   - compute shader: UNORDERED_ACCESS
//   - copy command: COPY_SOURCE or COPY_DEST
// - resource flags ALLOW_UNORDERED_ACCESS
//
// output buffer:
// - always in state COPY_DEST
// - resource flags NONE

public enum BufferType {
  // CPU can write, GPU cannot access in a compute shader.
  case input
  
  // GPU memory accesses are fast.
  case native
  
  // CPU can read, GPU cannot access in a compute shader.
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
  
  var initialResourceStates: D3D12_RESOURCE_STATES {
    switch self {
    case .input:
      return D3D12_RESOURCE_STATE_GENERIC_READ
    case .native:
      return D3D12_RESOURCE_STATE_COMMON
    case .output:
      return D3D12_RESOURCE_STATE_COPY_DEST
    }
  }
  
  var resourceFlags: D3D12_RESOURCE_FLAGS {
    switch self {
    case .input:
      return D3D12_RESOURCE_FLAG_NONE
    case .native:
      return D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS
    case .output:
      return D3D12_RESOURCE_FLAG_NONE
    }
  }
}

public class Buffer {
  public let d3d12Resource: SwiftCOM.ID3D12Resource
  public let size: Int
  public let type: BufferType
  
  // Temporarily making this public for debugging purposes.
  public let mappedPointer: UnsafeMutableRawPointer?
  
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
    resourceDesc.Flags = type.resourceFlags
    
    // Create the resource.
    let d3d12Device = device.d3d12Device
    self.d3d12Resource = try! d3d12Device.CreateCommittedResource(
      heapProperties,
      D3D12_HEAP_FLAG_NONE,
      resourceDesc,
      type.initialResourceStates,
      nil)
    
    // Map the pointer for CPU access.
    if type == .input || type == .output {
      let mappedPointer = try! d3d12Resource.Map(0, nil)
      self.mappedPointer = mappedPointer
    } else {
      self.mappedPointer = nil
    }
  }
  
  deinit {
    if type == .input || type == .output {
      try! d3d12Resource.Unmap(0, nil)
    }
  }
  
  /// Write data to the buffer.
  ///
  /// The entered memory allocation must span at least 'size' bytes.
  ///
  /// The data must be the input to a future GPU copy command.
  public func write(input: UnsafeRawPointer) {
    guard type == .input else {
      fatalError("Can only write to input buffers.")
    }
    memcpy(mappedPointer, input, size)
  }
  
  /// Read data from the buffer.
  ///
  /// The entered memory allocation must span at least 'size' bytes.
  ///
  /// The data must be the output of a previous GPU copy command.
  public func read(output: UnsafeMutableRawPointer) {
    guard type == .output else {
      fatalError("Can only read from output buffers.")
    }
    memcpy(output, mappedPointer, size)
  }
}

#endif

#if os(macOS)
import Metal
#else
import SwiftCOM
import WinSDK
#endif

public struct BufferDescriptor {
  public var device: Device?
  public var size: Int = .zero
  public var type: BufferType?
  
  public init() {
    
  }
}

public enum BufferType {
  #if os(Windows)
  /// CPU can write, GPU cannot access in a compute shader.
  case input
  #endif
  
  /// GPU memory accesses are fast.
  case native
  
  #if os(Windows)
  /// CPU can read, GPU cannot access in a compute shader.
  case output
  #endif
  
  #if os(Windows)
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
  
  var initialState: D3D12_RESOURCE_STATES {
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
  #endif
}

public class Buffer {
  #if os(macOS)
  public let mtlBuffer: MTLBuffer
  #else
  public let d3d12Resource: SwiftCOM.ID3D12Resource
  #endif
  public let size: Int
  public let type: BufferType
  
  #if os(Windows)
  private(set) var state: D3D12_RESOURCE_STATES
  private let mappedPointer: UnsafeMutableRawPointer?
  #endif
  
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
    
    #if os(macOS)
    // Create the buffer.
    let mtlBuffer = device.mtlDevice
      .makeBuffer(length: size)
    guard let mtlBuffer else {
      fatalError("Failed to create buffer.")
    }
    self.mtlBuffer = mtlBuffer
    #endif
    
    #if os(Windows)
    // Fill the heap properties.
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
    self.d3d12Resource =
    try! device.d3d12Device.CreateCommittedResource(
      heapProperties, // pHeapProperties
      D3D12_HEAP_FLAG_NONE, // HeapFlags
      resourceDesc, // pDesc
      type.initialState, // InitialResourceState
      nil) // pOptimizedClearValue
    
    // Initialize the state.
    self.state = type.initialState
    
    // Map the pointer for CPU access.
    if type == .input || type == .output {
      let mappedPointer = try! d3d12Resource.Map(0, nil)
      self.mappedPointer = mappedPointer
    } else {
      self.mappedPointer = nil
    }
    #endif
  }
  
  deinit {
    #if os(Windows)
    if type == .input || type == .output {
      try! d3d12Resource.Unmap(0, nil)
    }
    #endif
  }
  
  /// Write data to the buffer.
  ///
  /// The entered memory allocation must span at least 'size' bytes.
  ///
  /// The data must be the input to a future GPU copy command.
  public func write(input: UnsafeRawPointer) {
    #if os(macOS)
    let mappedPointer = mtlBuffer.contents()
    #else
    guard type == .input else {
      fatalError("Can only write to input buffers.")
    }
    #endif
    memcpy(mappedPointer, input, size)
  }
  
  /// Read data from the buffer.
  ///
  /// The entered memory allocation must span at least 'size' bytes.
  ///
  /// The data must be the output of a previous GPU copy command.
  public func read(output: UnsafeMutableRawPointer) {
    #if os(macOS)
    let mappedPointer = mtlBuffer.contents()
    #else
    guard type == .output else {
      fatalError("Can only read from output buffers.")
    }
    #endif
    memcpy(output, mappedPointer, size)
  }
  
  #if os(Windows)
  /// Transition the buffer's state to the specified value, then return a
  /// barrier representing the transition.
  ///
  /// Never call this function if it will transition between two identical
  /// states. As of writing, it is assumed that client code will always be able
  /// to anticipate the resource state.
  public func transition(
    state: D3D12_RESOURCE_STATES
  ) -> D3D12_RESOURCE_BARRIER {
    // Inspect whether the before and after states are the same.
    guard state != self.state else {
      fatalError(
        "Attempted a redundant transition between two identical states.")
    }
    
    // Specify the type of barrier.
    var barrier = D3D12_RESOURCE_BARRIER()
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
    
    // Specify the transition's parameters.
    try! d3d12Resource.perform(
      as: WinSDK.ID3D12Resource.self
    ) { pUnk in
      barrier.Transition.pResource = pUnk
    }
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    barrier.Transition.StateBefore = self.state
    barrier.Transition.StateAfter = state
    
    // Overwrite the current state with the new state.
    self.state = state
    
    // Return the barrier.
    return barrier
  }
  #endif
}

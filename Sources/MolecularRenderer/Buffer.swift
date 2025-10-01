#if os(macOS)
import Metal
#else
import SwiftCOM
import WinSDK
#endif

struct BufferDescriptor {
  var device: Device?
  var size: Int?
  var type: BufferType?
}

enum BufferAccessLevel {
  // GPU can only read.
  case constant
  
  // GPU can both read and write.
  case device
}

enum BufferType {
  #if os(Windows)
  /// CPU can write, GPU cannot access in a compute shader.
  case input
  #endif
  
  /// GPU memory accesses are fast.
  case native(BufferAccessLevel)
  
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
    case .native(.constant):
      return D3D12_RESOURCE_FLAG_NONE
    case .native(.device):
      return D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS
    case .output:
      return D3D12_RESOURCE_FLAG_NONE
    }
  }
  #endif
}

class Buffer {
  #if os(macOS)
  let mtlBuffer: MTLBuffer
  #else
  let d3d12Resource: SwiftCOM.ID3D12Resource
  #endif
  let size: Int
  let type: BufferType
  
  #if os(Windows)
  private(set) var state: D3D12_RESOURCE_STATES
  private let mappedPointer: UnsafeMutableRawPointer?
  #endif
  
  init(descriptor: BufferDescriptor) {
    guard let device = descriptor.device,
          let size = descriptor.size,
          let type = descriptor.type else {
      fatalError("Descriptor was incomplete.")
    }
    self.type = type
    
    // Check that the size is valid.
    guard size > 0 else {
      fatalError("Buffer size must be nonzero.")
    }
    self.size = size
    
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
    switch type {
    case .input, .output:
      let mappedPointer = try! d3d12Resource.Map(0, nil)
      self.mappedPointer = mappedPointer
    default:
      self.mappedPointer = nil
    }
    #endif
  }
  
  deinit {
    #if os(Windows)
    switch type {
    case .input, .output:
      try! d3d12Resource.Unmap(0, nil)
    default:
      break
    }
    #endif
  }
  
  /// Write data to the buffer.
  ///
  /// The data must be the input to a future GPU copy command.
  func write(input: UnsafeRawBufferPointer) {
    guard let baseAddress = input.baseAddress else {
      fatalError("Input was invalid.")
    }
    guard input.count <= size else {
      fatalError("Input exceeded buffer allocation size.")
    }
    
    #if os(macOS)
    let mappedPointer = mtlBuffer.contents()
    #else
    switch type {
    case .input:
      break
    default:
      fatalError("Can only write to input buffers.")
    }
    #endif
    
    memcpy(mappedPointer, baseAddress, input.count)
  }
  
  /// Read data from the buffer.
  ///
  /// The data must be the output of a previous GPU copy command.
  func read(output: UnsafeMutableRawBufferPointer) {
    guard let baseAddress = output.baseAddress else {
      fatalError("Input was invalid.")
    }
    guard output.count <= size else {
      fatalError("Input exceeded buffer allocation size.")
    }
    
    #if os(macOS)
    let mappedPointer = mtlBuffer.contents()
    #else
    switch type {
    case .output:
      break
    default:
      fatalError("Can only read from output buffers.")
    }
    #endif
    
    memcpy(baseAddress, mappedPointer, output.count)
  }
  
  #if os(Windows)
  /// Transition the buffer's state to the specified value, then return a
  /// barrier representing the transition.
  ///
  /// Never call this function if it will transition between two identical
  /// states. As of writing, it is assumed that client code will always be able
  /// to anticipate the resource state.
  func transition(
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

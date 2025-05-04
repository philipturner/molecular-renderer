#if os(Windows)
import SwiftCOM
import WinSDK

// Exercise in usage of the DirectX 12 API.
// Implementing the UploadBuffer API design from:
// https://www.3dgep.com/learning-directx-12-3/#uploadbuffer-class
// As literal of a translation as possible from the C++ origin.

public class UploadBuffer {
  // MARK: - Private
  
  private var pagePool: [Page] = []
  private var availablePages: [Page] = []
  private var currentPage: Page?
  
  // The size of each page in memory.
  private var pageSize: Int
  
  // MARK: - Public
  
  /// Use to upload data to the GPU.
  public struct Allocation {
    public var CPU: UnsafeMutableRawPointer?
    public var GPU: UInt64 = 0
  }
  
  /// - Parameter pageSize: The size to use to allocate new pages in GPU memory.
  public init(pageSize: Int = 2 * 1024 * 1024) {
    self.pageSize = pageSize
  }
  
  /// The maximum size of an allocation is the size of a single page.
  public func GetPageSize() -> Int {
    return pageSize
  }
  
  /// Allocate memory in an Upload heap.
  ///
  /// An allocation must not exceed the size of a page. Use a memcpy or similar
  /// method to copy the buffer data to CPU pointer in the Allocation structure
  /// returned from this function.
  public func Allocate(
    sizeInBytes: Int,
    alignment: Int
  ) -> Allocation {
    guard sizeInBytes <= pageSize else {
      fatalError("Allocation size exceeded page size.")
    }
    
    // If there is no current page, or the requested allocation exceeds the
    // remaining space in the current page, request a new page.
    var shouldRequestPage = true
    if let currentPage {
      let hasSpace = currentPage.HasSpace(
        sizeInBytes: sizeInBytes, alignment: alignment)
      
      if hasSpace {
        shouldRequestPage = false
      }
    }
    if shouldRequestPage {
      currentPage = RequestPage()
    }
    
    // Avoid confusion from a name conflict with the stored property,
    // 'currentPage'.
    guard let requestedPage = currentPage else {
      fatalError("This should never happen.")
    }
    let allocation = requestedPage.Allocate(
      sizeInBytes: sizeInBytes, alignment: alignment)
    return allocation
  }
  
  /// Release all allocated pages. This should only be done when the command
  /// list is finished executing on the CommandQueue.
  public func Reset() {
    currentPage = nil
    
    // Reset all available pages.
    availablePages = pagePool
    
    // Pages are reference types ('class'), so you can mutate their contents
    // while outside the list. This design choice doesn't mesh well with Swift.
    for page in availablePages {
      // Reset the page for new allocations.
      page.Reset()
    }
  }
  
  // MARK: - Private
  
  // Request a page from the pool of available pages or create a new page if
  // there are no available pages.
  private func RequestPage() -> Page {
    var output: Page
    
    if availablePages.count > 0 {
      // Retrieve a page from the cache.
      let removedPage = availablePages.first!
      availablePages.removeFirst()
      
      output = removedPage
    } else {
      // Add a new page to the cache.
      let newPage = Page(sizeInBytes: pageSize)
      pagePool.append(newPage)
      
      output = newPage
    }
    
    return output
  }
}

// A single page for the allocator.
extension UploadBuffer {
  class Page {
    // MARK: - Private
    
    private var d3d12Resource: SwiftCOM.ID3D12Resource
    
    // Base pointer.
    private var CPUPtr: UnsafeMutableRawPointer?
    private var GPUPtr: UInt64
    
    // Allocated page size.
    private var pageSize: Int
    
    // Current allocation offset in bytes.
    private var offset: Int
    
    // MARK: - Public
    
    init(sizeInBytes: Int) {
      self.pageSize = sizeInBytes
      self.offset = 0
      self.CPUPtr = nil
      self.GPUPtr = 0
      
      // Not concerning myself with how to reference the global DirectX device.
      func createGlobalDevice() -> SwiftCOM.ID3D12Device {
        fatalError("Ignoring the implementation.")
      }
      
      // Utility function for creating a committed resource.
      func createHeapProperties(
        type: D3D12_HEAP_TYPE
      ) -> D3D12_HEAP_PROPERTIES {
        var heapProperties = D3D12_HEAP_PROPERTIES()
        heapProperties.Type = type
        heapProperties.CPUPageProperty = D3D12_CPU_PAGE_PROPERTY_UNKNOWN
        heapProperties.MemoryPoolPreference = D3D12_MEMORY_POOL_UNKNOWN
        heapProperties.CreationNodeMask = 0
        heapProperties.VisibleNodeMask = 0
        
        return heapProperties
      }
      
      // Utility function for creating a committed resource.
      func createResourceDesc(size: Int) -> D3D12_RESOURCE_DESC {
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
        resourceDesc.Flags = D3D12_RESOURCE_FLAG_NONE
        
        return resourceDesc
      }
            
      // Create the committed resource.
      func createCommittedResource(size: Int) -> SwiftCOM.ID3D12Resource {
        let device = createGlobalDevice()
        let heapProperties = createHeapProperties(type: D3D12_HEAP_TYPE_UPLOAD)
        let resourceDesc = createResourceDesc(size: size)
        
        let resource: SwiftCOM.ID3D12Resource =
        try! device.CreateCommittedResource(
          heapProperties,
          D3D12_HEAP_FLAG_NONE,
          resourceDesc,
          D3D12_RESOURCE_STATE_GENERIC_READ,
          nil)
        return resource
      }
      
      self.d3d12Resource = createCommittedResource(size: pageSize)
      self.CPUPtr = try! d3d12Resource.Map(0, nil)
      self.GPUPtr = try! d3d12Resource.GetGPUVirtualAddress()
    }
    
    deinit {
      try! d3d12Resource.Unmap(0, nil)
      CPUPtr = nil
      GPUPtr = 0
    }
    
    // Check to see if the page has room to satisfy the requested allocation.
    func HasSpace(
      sizeInBytes: Int,
      alignment: Int
    ) -> Bool {
      // Utility function for rounding integers up.
      func alignUp(size: Int, alignment: Int) -> Int {
        guard alignment > 0,
              alignment.nonzeroBitCount == 1 else {
          fatalError("Invalid alignment.")
        }
        
        let mask = alignment - 1
        return (size + mask) & ~mask
      }
      
      let alignedSize = alignUp(
        size: sizeInBytes, alignment: alignment)
      let alignedOffset = alignUp(
        size: offset, alignment: alignment)
      
      let allocationEnd = alignedOffset + alignedSize
      return allocationEnd <= pageSize
    }
    
    // Allocate memory from the page.
    func Allocate(
      sizeInBytes: Int,
      alignment: Int
    ) -> Allocation {
      // It would be better to just have an internal utility that reports the
      // end of buffer. That way, the boolean comparison can be made explicitly
      // in the caller.
      let canAllocateSpace = HasSpace(
        sizeInBytes: sizeInBytes, alignment: alignment)
      guard canAllocateSpace else {
        fatalError("Can't allocate space from page.")
      }
      
      // Utility function for rounding integers up.
      func alignUp(size: Int, alignment: Int) -> Int {
        guard alignment > 0,
              alignment.nonzeroBitCount == 1 else {
          fatalError("Invalid alignment.")
        }
        
        let mask = alignment - 1
        return (size + mask) & ~mask
      }
      
      // Utility function for adding to a CPU pointer.
      func addCPUPtr(
        _ CPUPtr: UnsafeMutableRawPointer?,
        offset: Int
      ) -> UnsafeMutableRawPointer {
        // This API ought to be refactored, so the CPU pointer is not nullable.
        guard let CPUPtr else {
          fatalError("CPU pointer was invalid.")
        }
        
        let casted = CPUPtr.assumingMemoryBound(to: UInt8.self)
        let incremented = casted + offset
        return UnsafeMutableRawPointer(casted)
      }
      
      // First, round up the internal offset.
      let alignedSize = alignUp(
        size: sizeInBytes, alignment: alignment)
      self.offset = alignUp(
        size: offset, alignment: alignment)
      
      // Assign the internal offst to the pointers.
      var allocation = Allocation()
      allocation.CPU = addCPUPtr(CPUPtr, offset: offset)
      allocation.GPU = GPUPtr + UInt64(offset)
      
      // Then, add the allocation size to the internal offset.
      self.offset += alignedSize
      
      return allocation
    }
    
    // Reset the page for reuse.
    func Reset() {
      self.offset = 0
    }
  }
}


#endif

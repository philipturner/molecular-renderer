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
    public var GPU: UInt64
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
      fatalError("Not implemented.")
    }
    
    deinit {
      fatalError("Not implemented.")
    }
    
    // Check to see if the page has room to satisfy the requested allocation.
    func HasSpace(
      sizeInBytes: Int,
      alignment: Int
    ) -> Bool {
      fatalError("Not implemented.")
    }
    
    // Allocate memory from the page.
    func Allocate(
      sizeInBytes: Int,
      alignment: Int
    ) -> Allocation {
      fatalError("Not implemented.")
    }
    
    // Reset the page for reuse.
    func Reset() {
      fatalError("Not implemented.")
    }
  }
}


#endif

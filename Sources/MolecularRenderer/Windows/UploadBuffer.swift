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
    fatalError("Not implemented.")
  }
  
  /// The maximum size of an allocation is the size of a single page.
  public func GetPageSize() -> Int {
    fatalError("Not implemented.")
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
    fatalError("Not implemented.")
  }
  
  /// Release all allocated pages. This should only be done when the command
  /// list is finished executing on the CommandQueue.
  public func Reset() {
    fatalError("Not implemented.")
  }
  
  // MARK: - Private
  
  // Request a page from the pool of available pages or create a new page if
  // there are no available pages.
  private func RequestPage() -> Page {
    fatalError("Not implemented.")
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

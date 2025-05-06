#if os(Windows)
import SwiftCOM
import WinSDK

// Exercise in usage of the DirectX 12 API.
// Implementing the DescriptorAllocator API design from:
// https://www.3dgep.com/learning-directx-12-3/#Descriptor_Allocator
// As literal of a translation as possible from the C++ origin.

public class DescriptorAllocator {
  // MARK: - Private
  
  private var heapType: D3D12_DESCRIPTOR_HEAP_TYPE
  private var numDescriptorsPerHeap: UInt32
  private var heapPool: [DescriptorAllocatorPage] = []
  
  // Indices of available heaps in the pool.
  private var availableHeaps: Set<Int> = []
  
  // MARK: - Public
  
  public init(
    type: D3D12_DESCRIPTOR_HEAP_TYPE,
    numDescriptorsPerHeap: UInt32 = 256
  ) {
    self.heapType = type
    self.numDescriptorsPerHeap = numDescriptorsPerHeap
  }
  
  /// Allocate a number of contiguous descriptors from a CPU visible descriptor
  /// heap.
  /// - Parameter numDescriptors: The number of contiguous descriptors to
  ///   allocate. Cannot be more than the number of descriptors per descriptor
  ///   heap.
  public func Allocate(
    numDescriptors: UInt32 = 1
  ) -> DescriptorAllocation {
    // Declare a descriptor with the null initializer. This clashes with Swift's
    // typical use of the Optional<> type. It would be simpler to declare the
    // allocation as 'nil'.
    //
    // It was so bad that I had to modify the interface to DescriptorAllocation.
    var allocation: DescriptorAllocation?
    
    // Iterate through the heaps, while at the same time resizing the heaps
    // list. This approach creates a lot of confusion.
    //
    // It was so bad that I had to rewrite the function from scratch.
    for availableHeapID in availableHeaps {
      // Retrieve the allocator page.
      let allocatorPage = heapPool[availableHeapID]
      
      // Create and inspect the allocation.
      let candidateAllocation = allocatorPage.Allocate(
        numDescriptors: numDescriptors)
      if let candidateAllocation {
        allocation = candidateAllocation
        break
      }
    }
    
    // Garbage collect the heaps after possibly modifying one of them.
    PurgeAvailableHeaps()
    
    // No available heap could satisfy the requested number of descriptors.
    if allocation == nil {
      // Grow the internal variable for descriptors per heap.
      if numDescriptors > numDescriptorsPerHeap {
        numDescriptorsPerHeap = numDescriptors
      }
      
      // Create a new page.
      let newPage = CreateAllocatorPage()
      
      // Create an allocation.
      let candidateAllocation = newPage.Allocate(
        numDescriptors: numDescriptors)
      
      // The candidate allocation should always be created successfully. Merge
      // the failure test with the other case, where failure should never
      // happen.
      allocation = candidateAllocation
    }
    
    // Execute a precondition. It is guaranteed to never be 'nil'.
    guard let allocation else {
      fatalError("This should never happen.")
    }
    return allocation
  }
  
  /// When the frame has completed, the stale descriptors can be released.
  public func ReleaseStaleDescriptors(
    frameNumber: UInt64
  ) {
    // Iterate through all of the heaps.
    for heapID in heapPool.indices {
      // Retrieve the page.
      let page = heapPool[heapID]
      
      // Modify the page.
      page.ReleaseStaleDescriptors(
        frameNumber: frameNumber)
    }
    
    // Garbage collect the heaps after possibly modifying one of them.
    RefreshAvailableHeaps()
  }
  
  // MARK: - Private
  
  // Create a new heap with a specific number of descriptors.
  private func CreateAllocatorPage() -> DescriptorAllocatorPage {
    let newPage = DescriptorAllocatorPage(
      type: heapType,
      numDescriptors: numDescriptorsPerHeap)
    let availableHeapID = heapPool.count
    
    heapPool.append(newPage)
    availableHeaps.insert(availableHeapID)
    
    return newPage
  }
  
  // TODO: Merge these two methods into one. Or, even better, transform the
  // 'available heaps' set into a computed property.
  
  // Separate pass to clean up the heaps list.
  private func PurgeAvailableHeaps() {
    // Iterate through the available pages.
    var removedFromAvailable: [Int] = []
    for availableHeapID in availableHeaps {
      // Retrieve the allocator page.
      let allocatorPage = heapPool[availableHeapID]
      
      // Inspect the allocator page.
      if allocatorPage.NumFreeHandles() == 0 {
        removedFromAvailable.append(availableHeapID)
      }
    }
    
    // Remove the invalid heaps.
    for removedHeapID in removedFromAvailable {
      availableHeaps.remove(removedHeapID)
    }
  }
  
  // Separate pass to clean up the heaps list.
  private func RefreshAvailableHeaps() {
    // Iterate through all of the heaps.
    var addedToAvailable: [Int] = []
    for heapID in heapPool.indices {
      // Retrieve the page.
      let page = heapPool[heapID]
      
      // Inspect the page.
      if page.NumFreeHandles() > 0 {
        addedToAvailable.append(heapID)
      }
    }
    
    // Add the valid heaps.
    for addedHeapID in addedToAvailable {
      availableHeaps.insert(addedHeapID)
    }
  }
}

#endif

#if os(Windows)
import SwiftCOM
import WinSDK

// Exercise in usage of the DirectX 12 API.
// Implementing the DescriptorAllocator API design from:
// https://www.3dgep.com/learning-directx-12-3/#Descriptor_Allocator
// As literal of a translation as possible from the C++ origin.

public class DescriptorAllocatorPage {
  // MARK: - Private
  
  // A map that lists the free blocks by the offset within the descriptor heap.
  private var freeListByOffset: [OffsetType: FreeBlockInfo] = [:]
  
  // A map that lists the free blocks by size.
  //
  // Needs to be a multimap since multiple blocks can have the same size.
  private var freeListBySize: [SizeType: [OffsetType]] = [:]
  
  // Stale descriptors are queued for release until the frame that they were
  // freed has completed.
  private var staleDescriptors: [StaleDescriptorInfo] = []
  
  private var d3d12DescriptorHeap: SwiftCOM.ID3D12DescriptorHeap
  private var heapType: D3D12_DESCRIPTOR_HEAP_TYPE
  private var baseDescriptor: D3D12_CPU_DESCRIPTOR_HANDLE
  private var descriptorHandleIncrementSize: UInt32
  private var numDescriptorsInHeap: UInt32
  private var numFreeHandles: UInt32
  
  // MARK: - Public
  
  public init(
    type: D3D12_DESCRIPTOR_HEAP_TYPE,
    numDescriptors: UInt32
  ) {
    self.heapType = type
    self.numDescriptorsInHeap = numDescriptors
    
    // Not concerning myself with how to reference the global DirectX device.
    func createGlobalDevice() -> SwiftCOM.ID3D12Device {
      fatalError("Ignoring the implementation.")
    }
    
    do {
      // Create a heap descriptor.
      var heapDesc = D3D12_DESCRIPTOR_HEAP_DESC()
      heapDesc.Type = type
      heapDesc.NumDescriptors = numDescriptors
      
      // Create the descriptor heap.
      let device = createGlobalDevice()
      d3d12DescriptorHeap = try! device.CreateDescriptorHeap(
        heapDesc)
    }
    
    // Assign the remaining stored properties.
    do {
      baseDescriptor = try! d3d12DescriptorHeap
        .GetCPUDescriptorHandleForHeapStart()
      
      let device = createGlobalDevice()
      descriptorHandleIncrementSize = try! device
        .GetDescriptorHandleIncrementSize(heapType)
      
      numFreeHandles = numDescriptorsInHeap
    }
    
    // Initialize the free lists.
    AddNewBlock(offset: 0, numDescriptors: numFreeHandles)
  }
  
  public func GetHeapType() -> D3D12_DESCRIPTOR_HEAP_TYPE {
    return heapType
  }
  
  /// Check to see if this descriptor page has a contiguous block of descriptors
  /// large enough to satisfy the request.
  public func HasSpace(
    numDescriptors: UInt32
  ) -> Bool {
    // Retrieve the offsets.
    let offsetsForSize = freeListBySize[numDescriptors]
    
    // Branch on whether the offsets are nil.
    if let offsetsForSize {
      return offsetsForSize.count > 0
    } else {
      return false
    }
  }
  
  /// Get the number of available handles in the heap.
  public func NumFreeHandles() -> UInt32 {
    return numFreeHandles
  }
  
  /// Allocate a number of descriptors from this descriptor heap.
  ///
  /// If the allocation cannot be satisfied, then a NULL descriptor is returned.
  public func Allocate(
    numDescriptors: UInt32
  ) -> DescriptorAllocation? {
    // There are less than the requested number of descriptors left in the heap.
    // Return a NULL descriptor and try another heap.
    if numDescriptors > numFreeHandles {
      return nil
    }
    
    // Get the first block that is large enough to satisfy the request.
    do {
      // The C++ std::map::lower_bound function is too complex for now.
      // Reverting from an O(logn) to an O(nlogn) algorithm for simplicity.
      let unsortedKeys = Array(freeListBySize.keys)
      
      // Sort the keys in ascending order.
      let sortedKeys = unsortedKeys.sorted(by: { $0 < $1 })
      
      // Iterate over the keys, searching for the smallest size whose list
      // contains elements.
      fatalError("Not implemented.")
    }
  }
  
  /// Return a descriptor back to the heap.
  /// - Parameter frameNumber: Stale descriptors are not freed directly, but put
  ///   on a stale allocations queue. Stale allocations are returned to the heap
  ///   using the DescriptorAllocatorPage::ReleaseStaleAllocations method.
  public func Free(
    descriptorHandle: inout DescriptorAllocation,
    frameNumber: UInt64
  ) {
    fatalError("Not implemented.")
  }
  
  /// Returned the stale descriptors back to the descriptor heap.
  public func ReleaseStaleDescriptors(
    frameNumber: UInt64
  ) {
    fatalError("Not implemented.")
  }
  
  // MARK: - Protected
  
  // Compute the offset of the descriptor handle from the start of the heap.
  private func ComputeOffset(
    handle: D3D12_CPU_DESCRIPTOR_HANDLE
  ) -> UInt32 {
    fatalError("Not implemented.")
  }
  
  // Adds a new block to the free list.
  private func AddNewBlock(
    offset: UInt32,
    numDescriptors: UInt32
  ) {
    // If a block list for the specified size doesn't exist, create a new one.
    do {
      let sizeList = freeListBySize[numDescriptors]
      if sizeList == nil {
        freeListBySize[numDescriptors] = []
      }
    }
    
    var freeListBySizeIt: UInt32
    
    do {
      // Retrieve the list of blocks.
      let sizeList = freeListBySize[numDescriptors]
      guard var sizeList else {
        fatalError("This size list should exist.")
      }
      
      // Retrieve the new block's position in the size list.
      freeListBySizeIt = UInt32(sizeList.count)
      
      // Append the new entry.
      sizeList.append(offset)
      
      // Return the list to its origin.
      freeListBySize[numDescriptors] = sizeList
    }
    
    // Create a new block, with an undefined 'freeListBySizeIt'.
    let newFreeBlock = FreeBlockInfo(
      size: numDescriptors,
      freeListBySizeIt: freeListBySizeIt)
    
    // Add a new entry at the specified offset. We assume that the caller has
    // already ensured it's okay to insert here.
    freeListByOffset[offset] = newFreeBlock
  }
  
  // Free a block of descriptors.
  //
  // This will also merge free blocks in the free list to form larger blocks
  // that can be reused.
  private func FreeBlock(
    offset: UInt32,
    numDescriptors: UInt32
  ) {
    fatalError("Not implemented.")
  }
}

extension DescriptorAllocatorPage {
  // The offset (in descriptors) within the descriptor heap.
  typealias OffsetType = UInt32
  
  // The number of descriptors that are available.
  typealias SizeType = UInt32
    
  struct FreeBlockInfo {
    var size: SizeType
    var freeListBySizeIt: UInt32
  }
  
  struct StaleDescriptorInfo {
    // The offset within the descriptor heap.
    var offset: OffsetType
    
    // The number of descriptors
    var size: SizeType
    
    // The frame number that the descriptor was freed.
    var frameNumber: UInt64
  }
}

#endif

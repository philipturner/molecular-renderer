#if os(Windows)
import SwiftCOM
import WinSDK

// Exercise in usage of the DirectX 12 API.
// Implementing the DescriptorAllocator API design from:
// https://www.3dgep.com/learning-directx-12-3/#Descriptor_Allocator
// As literal of a translation as possible from the C++ origin.

public struct DescriptorAllocatorPage {
  // MARK: - Private
  
  // A map that lists the free blocks by the offset within the descriptor heap.
  private var freeListByOffset: [OffsetType: FreeBlockInfo]
  
  // A map that lists the free blocks by size.
  //
  // Needs to be a multimap since multiple blocks can have the same size.
  private var freeListBySize: [SizeType: [OffsetType]]
  
  // Stale descriptors are queued for release until the frame that they were
  // freed has completed.
  private var staleDescriptors: [StaleDescriptorInfo]
  
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
    fatalError("Not implemented.")
  }
  
  public func GetHeapType() -> D3D12_DESCRIPTOR_HEAP_TYPE {
    fatalError("Not implemented.")
  }
  
  /// Check to see if this descriptor page has a contiguous block of descriptors
  /// large enough to satisfy the request.
  public func HasSpace(
    numDescriptors: UInt32
  ) -> Bool{
    fatalError("Not implemented.")
  }
  
  /// Get the number of available handles in the heap.
  public func NumFreeHandles() -> UInt32 {
    fatalError("Not implemented.")
  }
  
  /// Allocate a number of descriptors from this descriptor heap.
  ///
  /// If the allocation cannot be satisfied, then a NULL descriptor is returned.
  public mutating func Allocate(
    numDescriptors: UInt32
  ) -> DescriptorAllocation {
    fatalError("Not implemented.")
  }
  
  /// Return a descriptor back to the heap.
  /// - Parameter frameNumber: Stale descriptors are not freed directly, but put
  ///   on a stale allocations queue. Stale allocations are returned to the heap
  ///   using the DescriptorAllocatorPage::ReleaseStaleAllocations method.
  public mutating func Free(
    descriptorHandle: inout DescriptorAllocation,
    frameNumber: UInt64
  ) {
    fatalError("Not implemented.")
  }
  
  /// Returned the stale descriptors back to the descriptor heap.
  public mutating func ReleaseStaleDescriptors(
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
  private mutating func AddNewBlock(
    offset: UInt32,
    numDescriptors: UInt32
  ) {
    fatalError("Not implemented.")
  }
  
  // Free a block of descriptors.
  //
  // This will also merge free blocks in the free list to form larger blocks
  // that can be reused.
  private mutating func FreeBlock(
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
    var freeListBySizeIt: OffsetType = 0
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

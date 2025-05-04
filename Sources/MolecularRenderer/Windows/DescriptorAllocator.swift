#if os(Windows)
import SwiftCOM
import WinSDK

// Exercise in usage of the DirectX 12 API.
// Implementing the DescriptorAllocator API design from:
// https://www.3dgep.com/learning-directx-12-3/#Descriptor_Allocator
// As literal of a translation as possible from the C++ origin.

public struct DescriptorAllocator {
  // MARK: - Private
  
  // MARK: - Public
  
  public init(
    type: D3D12_DESCRIPTOR_HEAP_TYPE,
    numDescriptorsPerHeap: UInt32 = 256
  ) {
    fatalError("Not implemented.")
  }
  
  /// Allocate a number of contiguous descriptors from a CPU visible descriptor
  /// heap.
  /// - Parameter numDescriptors: The number of contiguous descriptors to
  ///   allocate. Cannot be more than the number of descriptors per descriptor
  ///   heap.
  public mutating func Allocate(
    numDescriptors: UInt32 = 1
  ) -> DescriptorAllocation {
    fatalError("Not implemented.")
  }
  
  /// When the frame has completed, the stale descriptors can be released.
  public mutating func ReleaseStaleDescriptors(
    frameNumber: UInt64
  ) {
    fatalError("Not implemented.")
  }
  
  // MARK: - Private
  
  private mutating func CreateAllocatorPage() -> DescriptorAllocatorPage {
    fatalError("Not implemented.")
  }
}

#endif

#if os(Windows)
import SwiftCOM
import WinSDK

// Exercise in usage of the DirectX 12 API.
// Implementing the DescriptorAllocator API design from:
// https://www.3dgep.com/learning-directx-12-3/#Descriptor_Allocator
// As literal of a translation as possible from the C++ origin.

public class DescriptorAllocation {
  // MARK: - Private
  
  // The base descriptor.
  var descriptor: D3D12_CPU_DESCRIPTOR_HANDLE
  
  // The number of descriptors in this allocation.
  var numHandles: UInt32
  
  // The offset to the next descriptor.
  var descriptorSize: UInt32
  
  // A pointer back to the original page where this allocation came from.
  var page: UnsafeMutablePointer<DescriptorAllocatorPage>
  
  // MARK: - Public
  
  /// Creates a NULL descriptor.
  public init() {
    fatalError("Not implemented.")
  }
  
  // Unsure what to do regarding DescriptorAllocatorPage being a reference type.
  public init(
    descriptor: D3D12_CPU_DESCRIPTOR_HANDLE,
    numHandles: UInt32,
    descriptorSize: UInt32,
    page: UnsafeMutablePointer<DescriptorAllocatorPage>
  ) {
    fatalError("Not implemented.")
  }
  
  /// The destructor will automatically free the allocation.
  deinit {
    fatalError("Not implemented.")
  }
  
  /// Check if this is a valid descriptor.
  public func IsNull() -> Bool {
    fatalError("Not implemented.")
  }
  
  /// Get a descriptor at a particular offset in the allocation.
  public func GetDescriptorHandle(
    offset: UInt32 = 0
  ) -> D3D12_CPU_DESCRIPTOR_HANDLE {
    fatalError("Not implemented.")
  }
  
  /// Get the number of (consecutive) handles for this allocation.
  public func GetNumHandles() -> UInt32 {
    fatalError("Not implemented.")
  }
  
  /// Get the heap that this allocation came from.
  ///
  /// For internal use only.
  public func GetDescriptorAllocatorPage()
  -> UnsafeMutablePointer<DescriptorAllocatorPage> {
    fatalError("Not implemented.")
  }
  
  // MARK: - Private
  
  // Free the descriptor back to the heap it came from.
  private func Free() {
    fatalError("Not implemented.")
  }
}

#endif

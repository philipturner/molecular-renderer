#if os(Windows)
import SwiftCOM
import WinSDK

struct DescriptorHeapDescriptor {
  var device: Device?
  var count: Int?
}

public class DescriptorHeap {
  unowned let device: Device
  private var offset: Int = 0
  let count: Int
  let incrementSize: Int
  
  public let d3d12DescriptorHeap: SwiftCOM.ID3D12DescriptorHeap
  
  init(descriptor: DescriptorHeapDescriptor) {
    guard let device = descriptor.device,
          let count = descriptor.count else {
      fatalError("Descriptor was incomplete.")
    }
    self.device = device
    self.count = count
    self.incrementSize = Int(
      try! device.d3d12Device.GetDescriptorHandleIncrementSize(
        D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV))
    
    var descriptorHeapDesc = D3D12_DESCRIPTOR_HEAP_DESC()
    descriptorHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV
    descriptorHeapDesc.NumDescriptors = UInt32(count)
    descriptorHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE
    self.d3d12DescriptorHeap = try! device.d3d12Device.CreateDescriptorHeap(
      descriptorHeapDesc)
  }
  
  func reset() {
    offset = 0
  }
  
  // Encode a CPU descriptor and return its index in the heap.
  func createUAV(
    resource: SwiftCOM.ID3D12Resource,
    uavDesc: D3D12_UNORDERED_ACCESS_VIEW_DESC?
  ) -> Int {
    guard offset < count else {
      fatalError("Exceeded number of allocated descriptors.")
    }
    
    var cpuHandle = try! d3d12DescriptorHeap
      .GetCPUDescriptorHandleForHeapStart()
    cpuHandle.ptr += UInt64(offset * incrementSize)
    
    if let uavDesc {
      var uavDescCopy = uavDesc
      try! device.d3d12Device.CreateUnorderedAccessView(
        resource, // pResource
        nil, // pCounterResource,
        &uavDescCopy, // pDesc
        cpuHandle) // DestDescriptor
    } else {
      try! device.d3d12Device.CreateUnorderedAccessView(
        resource, // pResource
        nil, // pCounterResource,
        nil, // pDesc
        cpuHandle) // DestDescriptor
    }
    
    return 0
  }
}

#endif

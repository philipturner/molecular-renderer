#if os(Windows)
import SwiftCOM
import WinSDK

public struct DescriptorHeapDescriptor {
  public var device: Device?
  public var count: Int?
  
  public init() {
    
  }
}

public class DescriptorHeap {
  unowned let device: Device
  private(set) var offset: Int = 0
  let count: Int
  let incrementSize: Int
  
  public let d3d12DescriptorHeap: SwiftCOM.ID3D12DescriptorHeap
  
  public init(descriptor: DescriptorHeapDescriptor) {
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
  
  public func reset() {
    offset = 0
  }
  
  // Encode a CPU descriptor and return its index in the heap.
  public func createCBV(
    resource: SwiftCOM.ID3D12Resource,
    cbvDesc: D3D12_CONSTANT_BUFFER_VIEW_DESC
  ) -> Int {
    guard offset < count else {
      fatalError("Exceeded number of allocated descriptors.")
    }
    
    // Retrieve the CPU descriptor handle.
    var cpuHandle = try! d3d12DescriptorHeap
      .GetCPUDescriptorHandleForHeapStart()
    cpuHandle.ptr += UInt64(offset * incrementSize)
    
    // Create the CBV.
    var cbvDescCopy = cbvDesc
    try! device.d3d12Device.CreateConstantBufferView(
      &cbvDescCopy, // pDesc
      cpuHandle) // DestDescriptor
    
    // Process the offset / descriptor index.
    let output = offset
    offset += 1
    return output
  }
  
  // Encode a CPU descriptor and return its index in the heap.
  public func createUAV(
    resource: SwiftCOM.ID3D12Resource,
    uavDesc: D3D12_UNORDERED_ACCESS_VIEW_DESC?
  ) -> Int {
    guard offset < count else {
      fatalError("Exceeded number of allocated descriptors.")
    }
    
    // Retrieve the CPU descriptor handle.
    var cpuHandle = try! d3d12DescriptorHeap
      .GetCPUDescriptorHandleForHeapStart()
    cpuHandle.ptr += UInt64(offset * incrementSize)
    
    // Create the UAV.
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
    
    // Process the offset / descriptor index.
    let output = offset
    offset += 1
    return output
  }
}

extension CommandList {
  public func setDescriptorHeap(_ descriptorHeap: DescriptorHeap) {
    self.descriptorHeap = descriptorHeap
    
    try! d3d12CommandList.SetDescriptorHeaps(
      [descriptorHeap.d3d12DescriptorHeap])
  }
  
  public func setDescriptor(handleID: Int, index: Int) {
    guard let descriptorHeap else {
      fatalError("Descriptor heap was not set.")
    }
    guard handleID < descriptorHeap.offset else {
      fatalError("Exceeded number of written descriptors.")
    }
    
    // Retrieve the GPU descriptor handle.
    var gpuHandle = try! descriptorHeap.d3d12DescriptorHeap
      .GetGPUDescriptorHandleForHeapStart()
    gpuHandle.ptr += UInt64(handleID * descriptorHeap.incrementSize)
    
    // Bind to the specified index in the root signature.
    try! d3d12CommandList
      .SetComputeRootDescriptorTable(UInt32(index), gpuHandle)
  }
}

#endif

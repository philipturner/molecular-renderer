#if os(Windows)
import SwiftCOM
import WinSDK

struct DescriptorHeapDescriptor {
  var device: Device?
  var count: Int?
}

public class DescriptorHeap {
  private var offset: Int = 0
  private let count: Int
  private let incrementSize: Int
  
  public let d3d12DescriptorHeap: SwiftCOM.ID3D12DescriptorHeap
  
  init(descriptor: DescriptorHeapDescriptor) {
    guard let device = descriptor.device,
          let count = descriptor.count else {
      fatalError("Descriptor was incomplete.")
    }
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
}

#endif

#if os(Windows)
import SwiftCOM
import WinSDK

struct DescriptorHeapDescriptor {
  var device: Device?
  var count: Int?
}

class DescriptorHeap {
  private var offset: Int = 0
  private let incrementSize: Int
  
  init(descriptor: DescriptorHeapDescriptor) {
    guard let device = descriptor.device,
          let count = descriptor.count else {
      fatalError("Descriptor was incomplete.")
    }
    incrementSize = Int(
      try! device.d3d12Device.GetDescriptorHandleIncrementSize(
        D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV))
  }
}

#endif

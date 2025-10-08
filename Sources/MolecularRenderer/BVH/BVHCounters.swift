#if os(Windows)
import SwiftCOM
import WinSDK
#endif

struct BVHCountersDescriptor {
  var device: Device?
}

class BVHCounters {
  let crashBuffer: CrashBuffer // initialize at startup
  #if os(Windows)
  let queryHeap: SwiftCOM.ID3D12QueryHeap
  let queryDestinationBuffer: Buffer
  #endif
  
  init(descriptor: BVHCountersDescriptor) {
    guard let device = descriptor.device else {
      fatalError("Descriptor was incomplete.")
    }
    
    var crashBufferDesc = CrashBufferDescriptor()
    crashBufferDesc.device = device
    crashBufferDesc.size = 4096
    self.crashBuffer = CrashBuffer(descriptor: crashBufferDesc)
    
    #if os(Windows)
    self.queryHeap = Self.createQueryHeap(device: device)
    self.queryDestinationBuffer = Self
      .createQueryDestinationBuffer(device: device)
    #endif
  }
  
  #if os(Windows)
  static func createQueryHeap(
    device: Device
  ) -> SwiftCOM.ID3D12QueryHeap {
    var queryHeapDesc = D3D12_QUERY_HEAP_DESC()
    queryHeapDesc.Type = D3D12_QUERY_HEAP_TYPE_TIMESTAMP
    queryHeapDesc.Count = 64
    queryHeapDesc.NodeMask = 0
    
    var iid: IID = SwiftCOM.ID3D12QueryHeap.IID
    let pvHeap = try! device.d3d12Device.CreateQueryHeap(
      &queryHeapDesc, &iid)
    guard let pvHeap else {
      fatalError("Could not create query heap.")
    }
    return SwiftCOM.ID3D12QueryHeap(pUnk: pvHeap)
  }
  
  static func createQueryDestinationBuffer(
    device: Device
  ) -> Buffer {
    var bufferDesc = BufferDescriptor()
    bufferDesc.device = device
    bufferDesc.size = 64 * 8
    bufferDesc.type = .output
    return Buffer(descriptor: bufferDesc)
  }
  #endif
}

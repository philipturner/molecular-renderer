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
  //let queryHeap: SwiftCOM.ID3D12QueryHeap
  //let queryDestinationBuffer: Buffer
  #endif
  
  init(descriptor: BVHCountersDescriptor) {
    guard let device = descriptor.device else {
      fatalError("Descriptor was incomplete.")
    }
    
    var crashBufferDesc = CrashBufferDescriptor()
    crashBufferDesc.device = device
    crashBufferDesc.size = 4096
    self.crashBuffer = CrashBuffer(descriptor: crashBufferDesc)
  }
}

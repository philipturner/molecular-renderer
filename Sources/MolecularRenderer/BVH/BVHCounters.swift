#if os(Windows)
import SwiftCOM
import WinSDK
#endif

enum BVHCounterType {
  // TODO: Fill with more accurate descriptions of the counters.
  case garbageCollect
  
  // Offset (in bytes) of the counter, relative to the start of the buffer.
  var offset: Int {
    switch self {
    case .garbageCollect:
      return 0
    }
  }
}

struct BVHCountersDescriptor {
  var device: Device?
}

class BVHCounters {
  let crashBuffer: CrashBuffer // initialize at startup
  static var crashBufferSize: Int { 64 * 4 }
  let diagnosticBuffer: CrashBuffer // use to download data when debugging
  static var diagnosticBufferSize: Int { 4096 * 32 }
  
  #if os(Windows)
  let queryHeap: SwiftCOM.ID3D12QueryHeap
  let queryDestinationBuffer: Buffer
  #endif
  
  // A play on "General Nanomedics" from the Nanofactory Corporation LOL.
  let generalCounters: Buffer // purge to 0 before every frame
  
  init(descriptor: BVHCountersDescriptor) {
    guard let device = descriptor.device else {
      fatalError("Descriptor was incomplete.")
    }
    
    var crashBufferDesc = CrashBufferDescriptor()
    crashBufferDesc.device = device
    crashBufferDesc.size = BVHCounters.crashBufferSize
    self.crashBuffer = CrashBuffer(descriptor: crashBufferDesc)
    
    crashBufferDesc.size = BVHCounters.diagnosticBufferSize
    self.diagnosticBuffer = CrashBuffer(descriptor: crashBufferDesc)
    
    #if os(Windows)
    self.queryHeap = Self.createQueryHeap(device: device)
    self.queryDestinationBuffer = Self
      .createQueryDestinationBuffer(device: device)
    #endif
    
    var generalCountersDesc = BufferDescriptor()
    generalCountersDesc.device = device
    generalCountersDesc.size = 256 * 4
    generalCountersDesc.type = .native(.device)
    self.generalCounters = Buffer(descriptor: generalCountersDesc)
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
  
  // Clear certain lanes of indirect dispatch arguments to 1. This must happen
  // after the UAV barrier for the command that sets the entire buffer to 0.
  func setupGeneralCounters(commandList: CommandList) {
    
  }
}

#if os(Windows)
import SwiftCOM
import WinSDK
#endif

struct CounterResourcesDescriptor {
  var device: Device?
}

class CounterResources {
  let generalCounters: Buffer // purge in isolation from other resources
  
  let crashBuffer: CrashBuffer // initialize at startup
  static var crashBufferSize: Int { 64 * 4 }
  let diagnosticBuffer: CrashBuffer // use to download data when debugging
  static var diagnosticBufferSize: Int { GeneralCounters.totalSize }
  
  #if os(Windows)
  let queryHeap: SwiftCOM.ID3D12QueryHeap
  let queryDestinationBuffer: Buffer
  #endif
  
  init(descriptor: CounterResourcesDescriptor) {
    guard let device = descriptor.device else {
      fatalError("Descriptor was incomplete.")
    }
    
    var bufferDesc = BufferDescriptor()
    bufferDesc.device = device
    bufferDesc.size = GeneralCounters.totalSize
    bufferDesc.type = .native(.device)
    self.generalCounters = Buffer(descriptor: bufferDesc)
    
    var crashBufferDesc = CrashBufferDescriptor()
    crashBufferDesc.device = device
    crashBufferDesc.size = Self.crashBufferSize
    self.crashBuffer = CrashBuffer(descriptor: crashBufferDesc)
    
    crashBufferDesc.size = Self.diagnosticBufferSize
    self.diagnosticBuffer = CrashBuffer(descriptor: crashBufferDesc)
    
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
  
  func setupGeneralCounters(commandList: CommandList) {
    // Purge entire resource to 0
    
    // UAV barrier
    
    // Reset some sub-sections to 1
    
    // UAV barrier
  }
}

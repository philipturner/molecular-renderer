#if os(macOS)
import class Dispatch.DispatchQueue
#else
import SwiftCOM
import WinSDK
#endif

struct CounterResourcesDescriptor {
  var device: Device?
}

class CounterResources {
  let general: Buffer // purge in isolation from other resources
  let crashBuffer: CrashBuffer // initialize at startup
  static var crashBufferSize: Int { 64 * 4 }
  
  #if os(macOS)
  // Accesses to these are synchronized by the MTLCommandBuffer waiting
  // mechanism in CrashBuffer. The crash buffer must be checked before querying
  // performance counters.
  let queue: DispatchQueue
  var updateLatencies: [Int] = [0, 0, 0]
  var renderLatencies: [Int] = [0, 0, 0]
  var forgetLatencies: [Int] = [0, 0, 0]
  var upscaleLatencies: [Int] = [0, 0, 0]
  #else
  let queryHeap: SwiftCOM.ID3D12QueryHeap
  var queryDestinationBuffers: [Buffer] = []
  #endif
  
  init(descriptor: CounterResourcesDescriptor) {
    guard let device = descriptor.device else {
      fatalError("Descriptor was incomplete.")
    }
    
    var bufferDesc = BufferDescriptor()
    bufferDesc.device = device
    bufferDesc.size = GeneralCounters.totalSize
    bufferDesc.type = .native(.device)
    self.general = Buffer(descriptor: bufferDesc)
    
    var crashBufferDesc = CrashBufferDescriptor()
    crashBufferDesc.device = device
    crashBufferDesc.size = Self.crashBufferSize
    self.crashBuffer = CrashBuffer(descriptor: crashBufferDesc)
    
    #if os(macOS)
    let label = "CounterResources.queue"
    self.queue = DispatchQueue(label: label)
    #else
    self.queryHeap = Self.createQueryHeap(device: device)
    for _ in 0..<3 {
      let buffer = Self
        .createQueryDestinationBuffer(device: device)
      queryDestinationBuffers.append(buffer)
    }
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
      &queryHeapDesc, // pDesc
      &iid) // riid
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

extension BVHBuilder {
  func setupGeneralCounters(commandList: CommandList) {
    clearBuffer(
      commandList: commandList,
      clearValue: 0,
      clearedBuffer: counters.general,
      size: GeneralCounters.totalSize)
    
    #if os(Windows)
    computeUAVBarrier(commandList: commandList)
    #endif
    
    do {
      var offset = GeneralCounters.offset(.atomsRemovedVoxelCount)
      offset += 4
      clearBuffer(
        commandList: commandList,
        clearValue: UInt32(1),
        clearedBuffer: counters.general,
        size: 2 * 4,
        offset: offset)
    }
    
    do {
      var offset = GeneralCounters.offset(.rebuiltVoxelCount)
      offset += 4
      clearBuffer(
        commandList: commandList,
        clearValue: UInt32(1),
        clearedBuffer: counters.general,
        size: 2 * 4,
        offset: offset)
    }
    
    #if os(Windows)
    computeUAVBarrier(commandList: commandList)
    #endif
  }
}

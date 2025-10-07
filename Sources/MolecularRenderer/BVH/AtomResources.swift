#if os(Windows)
import SwiftCOM
import WinSDK
#endif

struct AtomResourcesDescriptor {
  var addressSpaceSize: Int?
  var device: Device?
}

class AtomResources {
  let addressSpaceSize: Int
  
  // Per atom address
  let atoms: Buffer
  let motionVectors: Buffer // purge to 0 with transaction tracking, idle/active
  let relativeOffsets1: Buffer
  let relativeOffsets2: Buffer
  #if os(Windows)
  var motionVectorsHandleID: Int = -1
  var relativeOffsets1HandleID: Int = -1
  var relativeOffsets2HandleID: Int = -1
  #endif
  
  // Per atom in transaction
  let transactionAtoms: RingBuffer
  let transactionIDs: RingBuffer
  
  init(descriptor: AtomResourcesDescriptor) {
    guard let addressSpaceSize = descriptor.addressSpaceSize,
          let device = descriptor.device else {
      fatalError("Descriptor was incomplete.")
    }
    self.addressSpaceSize = addressSpaceSize
    
    // Create a general purpose buffer that resides natively on the GPU.
    func createBuffer(size: Int) -> Buffer {
      var bufferDesc = BufferDescriptor()
      bufferDesc.device = device
      bufferDesc.size = size
      bufferDesc.type = .native(.device)
      return Buffer(descriptor: bufferDesc)
    }
    
    self.atoms = createBuffer(size: addressSpaceSize * 16)
    self.motionVectors = createBuffer(size: addressSpaceSize * 8)
    self.relativeOffsets1 = createBuffer(size: addressSpaceSize * 8)
    self.relativeOffsets2 = createBuffer(size: addressSpaceSize * 8)
    
    self.transactionAtoms = Self.createTransactionAtomsBuffer(
      device: device, maxTransactionSize: 1_000_000)
    self.transactionIDs = Self.createTransactionIDsBuffer(
      device: device, maxTransactionSize: 2_000_000)
  }
  
  private static func createTransactionAtomsBuffer(
    device: Device,
    maxTransactionSize: Int
  ) -> RingBuffer {
    var ringBufferDesc = RingBufferDescriptor()
    ringBufferDesc.accessLevel = .device
    ringBufferDesc.device = device
    ringBufferDesc.size = maxTransactionSize * 16
    return RingBuffer(descriptor: ringBufferDesc)
  }
  
  private static func createTransactionIDsBuffer(
    device: Device,
    maxTransactionSize: Int
  ) -> RingBuffer {
    var ringBufferDesc = RingBufferDescriptor()
    ringBufferDesc.accessLevel = .device
    ringBufferDesc.device = device
    ringBufferDesc.size = maxTransactionSize * 4
    return RingBuffer(descriptor: ringBufferDesc)
  }
}

#if os(Windows)
extension AtomResources {
  func encodeMotionVectors(descriptorHeap: DescriptorHeap) {
    var uavDesc = D3D12_UNORDERED_ACCESS_VIEW_DESC()
    uavDesc.Format = DXGI_FORMAT_R16G16B16A16_FLOAT
    uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER
    uavDesc.Buffer.FirstElement = 0
    uavDesc.Buffer.NumElements = UInt32(addressSpaceSize)
    uavDesc.Buffer.StructureByteStride = 0
    uavDesc.Buffer.CounterOffsetInBytes = 0
    uavDesc.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_NONE
    
    let handleID = descriptorHeap.createUAV(
      resource: motionVectors.d3d12Resource,
      uavDesc: uavDesc)
    self.motionVectorsHandleID = handleID
  }
  
  func encodeRelativeOffsets(descriptorHeap: DescriptorHeap) {
    var uavDesc = D3D12_UNORDERED_ACCESS_VIEW_DESC()
    uavDesc.Format = DXGI_FORMAT_R16G16B16A16_UINT
    uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER
    uavDesc.Buffer.FirstElement = 0
    uavDesc.Buffer.NumElements = UInt32(addressSpaceSize)
    uavDesc.Buffer.StructureByteStride = 0
    uavDesc.Buffer.CounterOffsetInBytes = 0
    uavDesc.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_NONE
    
    let handleID1 = descriptorHeap.createUAV(
      resource: relativeOffsets1.d3d12Resource,
      uavDesc: uavDesc)
    self.relativeOffsets1HandleID = handleID1
    
    let handleID2 = descriptorHeap.createUAV(
      resource: relativeOffsets2.d3d12Resource,
      uavDesc: uavDesc)
    self.relativeOffsets2HandleID = handleID2
  }
}
#endif

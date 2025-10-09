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
  let occupied: Buffer // initialize to 0 with shader
  let relativeOffsets1: Buffer
  let relativeOffsets2: Buffer
  #if os(Windows)
  var motionVectorsHandleID: Int = -1
  var relativeOffsets1HandleID: Int = -1
  var relativeOffsets2HandleID: Int = -1
  var occupiedHandleID: Int = -1
  #endif
  
  // Per atom in transaction
  let transactionIDs: RingBuffer
  let transactionAtoms: RingBuffer
  
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
    self.occupied = createBuffer(size: addressSpaceSize)
    self.relativeOffsets1 = createBuffer(size: addressSpaceSize * 8)
    self.relativeOffsets2 = createBuffer(size: addressSpaceSize * 8)
    
    self.transactionIDs = Self.createTransactionIDsBuffer(
      device: device, maxTransactionSize: 2_000_000)
    self.transactionAtoms = Self.createTransactionAtomsBuffer(
      device: device, maxTransactionSize: 1_000_000)
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
  
  func encodeOccupied(descriptorHeap: DescriptorHeap) {
    var uavDesc = D3D12_UNORDERED_ACCESS_VIEW_DESC()
    uavDesc.Format = DXGI_FORMAT_R8_UINT
    uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER
    uavDesc.Buffer.FirstElement = 0
    uavDesc.Buffer.NumElements = UInt32(addressSpaceSize)
    uavDesc.Buffer.StructureByteStride = 0
    uavDesc.Buffer.CounterOffsetInBytes = 0
    uavDesc.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_NONE
    
    let handleID = descriptorHeap.createUAV(
      resource: occupied.d3d12Resource,
      uavDesc: uavDesc)
    self.occupiedHandleID = handleID
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
  
  static var functionArguments: String {
    #if os(macOS)
    """
    constant TransactionArgs &transactionArgs [[buffer(0)]],
    device uint *transactionIDs [[buffer(1)]],
    device float4 *transactionAtoms [[buffer(2)]],
    device float4 *atoms [[buffer(3)]],
    device half4 *motionVectors [[buffer(4)]],
    device uchar *occupied [[buffer(5)]],
    device ushort4 *relativeOffsets1 [[buffer(6)]],
    device ushort4 *relativeOffsets2 [[buffer(7)]]
    """
    #else
    """
    ConstantBuffer<TransactionArgs> transactionArgs : register(b0);
    RWStructuredBuffer<uint> transactionIDs : register(u1);
    RWStructuredBuffer<float4> transactionAtoms : register(u2);
    RWStructuredBuffer<float4> atoms : register(u3);
    RWBuffer<float4> motionVectors : register(u4);
    RWBuffer<uint> occupied : register(u5);
    RWBuffer<uint4> relativeOffsets1 : register(u6);
    RWBuffer<uint4> relativeOffsets2 : register(u7);
    """
    #endif
  }
  
  #if os(Windows)
  static var rootSignatureArguments: String {
    """
    "RootConstants(b0, num32BitConstants = 3),"
    "UAV(u1),"
    "UAV(u2),"
    "UAV(u3),"
    "DescriptorTable(UAV(u4, numDescriptors = 1)),"
    "DescriptorTable(UAV(u5, numDescriptors = 1)),"
    "DescriptorTable(UAV(u6, numDescriptors = 1)),"
    "DescriptorTable(UAV(u7, numDescriptors = 1)),"
    """
  }
  #endif
}
#endif

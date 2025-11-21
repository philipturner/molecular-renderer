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
  static var maxTransactionSize: Int { 2_000_000 }
  
  // Per atom address
  let atoms: Buffer
  let motionVectors: Buffer // purge to 0 with transaction tracking, idle/active
  let addressOccupiedMarks: Buffer // initialize to 0 with shader
  let relativeOffsets1: Buffer
  let relativeOffsets2: Buffer
  #if os(Windows)
  var motionVectorsHandleID: Int?
  var addressOccupiedMarksHandleID: Int = -1
  var relativeOffsets1HandleID: Int = -1
  var relativeOffsets2HandleID: Int = -1
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
    self.addressOccupiedMarks = createBuffer(size: addressSpaceSize)
    self.relativeOffsets1 = createBuffer(size: Self.maxTransactionSize * 8)
    self.relativeOffsets2 = createBuffer(size: Self.maxTransactionSize * 8)
    
    self.transactionIDs = Self.createTransactionIDsBuffer(
      device: device, maxTransactionSize: 2 * Self.maxTransactionSize)
    self.transactionAtoms = Self.createTransactionAtomsBuffer(
      device: device, maxTransactionSize: Self.maxTransactionSize)
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
  func encodeMotionVectors(
    descriptorHeap: DescriptorHeap,
    supports16BitTypes: Bool
  ) {
    guard !supports16BitTypes else {
      return
    }

    // We have never encountered this error, but buffers may become large enough
    // to reach the 4 GB range at 500M atoms. So we proactively do this.
    let bufferByteCount = addressSpaceSize * 8
    guard bufferByteCount <= 4_000_000_000 else {
      fatalError("Will have a GPU suspended crash at runtime.")
    }

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
  
  func encodeAddressOccupiedMarks(descriptorHeap: DescriptorHeap) {
    var uavDesc = D3D12_UNORDERED_ACCESS_VIEW_DESC()
    uavDesc.Format = DXGI_FORMAT_R8_UINT
    uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER
    uavDesc.Buffer.FirstElement = 0
    uavDesc.Buffer.NumElements = UInt32(addressSpaceSize)
    uavDesc.Buffer.StructureByteStride = 0
    uavDesc.Buffer.CounterOffsetInBytes = 0
    uavDesc.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_NONE
    
    let handleID = descriptorHeap.createUAV(
      resource: addressOccupiedMarks.d3d12Resource,
      uavDesc: uavDesc)
    self.addressOccupiedMarksHandleID = handleID
  }
  
  func encodeRelativeOffsets(descriptorHeap: DescriptorHeap) {
    var uavDesc = D3D12_UNORDERED_ACCESS_VIEW_DESC()
    uavDesc.Format = DXGI_FORMAT_R16G16B16A16_UINT
    uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER
    uavDesc.Buffer.FirstElement = 0
    uavDesc.Buffer.NumElements = UInt32(Self.maxTransactionSize)
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

extension AtomResources {
  static func functionArguments(
    _ supports16BitTypes: Bool
  ) -> String {
    #if os(macOS)
    return """
    constant TransactionArgs &transactionArgs [[buffer(1)]],
    device uint *transactionIDs [[buffer(2)]],
    device float4 *transactionAtoms [[buffer(3)]],
    device float4 *atoms [[buffer(4)]],
    device half4 *motionVectors [[buffer(5)]],
    device uchar *addressOccupiedMarks [[buffer(6)]],
    device ushort4 *relativeOffsets1 [[buffer(7)]],
    device ushort4 *relativeOffsets2 [[buffer(8)]]
    """
    #else
    func motionVectorsArgumentType() -> String {
      if supports16BitTypes {
        return "RWStructuredBuffer<half4>"
      } else {
        return "RWBuffer<float4>"
      }
    }
    
    return """
    ConstantBuffer<TransactionArgs> transactionArgs : register(b1);
    RWStructuredBuffer<uint> transactionIDs : register(u2);
    RWStructuredBuffer<float4> transactionAtoms : register(u3);
    RWStructuredBuffer<float4> atoms : register(u4);
    \(motionVectorsArgumentType()) motionVectors : register(u5);
    RWBuffer<uint> addressOccupiedMarks : register(u6);
    RWBuffer<uint4> relativeOffsets1 : register(u7);
    RWBuffer<uint4> relativeOffsets2 : register(u8);
    """
    #endif
  }
  
  #if os(Windows)
  static func rootSignatureArguments(
    _ supports16BitTypes: Bool
  ) -> String {
    func motionVectorsRootSignatureArgument() -> String {
      if supports16BitTypes {
        return "UAV(u5)"
      } else {
        return "DescriptorTable(UAV(u5, numDescriptors = 1))"
      }
    }

    return """
    "RootConstants(b1, num32BitConstants = 3),"
    "UAV(u2),"
    "UAV(u3),"
    "UAV(u4),"
    "\(motionVectorsRootSignatureArgument()),"
    "DescriptorTable(UAV(u6, numDescriptors = 1)),"
    "DescriptorTable(UAV(u7, numDescriptors = 1)),"
    "DescriptorTable(UAV(u8, numDescriptors = 1)),"
    """
  }
  #endif
  
  func setBufferBindings(
    commandList: CommandList,
    inFlightFrameID: Int,
    transactionArgs: TransactionArgs
  ) {
    // Bind the transaction arguments.
    commandList.set32BitConstants(transactionArgs, index: 1)
    
    // Bind the transaction buffers.
    let idsBuffer = transactionIDs.nativeBuffers[inFlightFrameID]
    let atomsBuffer = transactionAtoms.nativeBuffers[inFlightFrameID]
    commandList.setBuffer(idsBuffer, index: 2)
    commandList.setBuffer(atomsBuffer, index: 3)
    
    // Bind the per-address buffers.
    commandList.setBuffer(atoms, index: 4)
    #if os(macOS)
    commandList.setBuffer(motionVectors, index: 5)
    commandList.setBuffer(addressOccupiedMarks, index: 6)
    commandList.setBuffer(relativeOffsets1, index: 7)
    commandList.setBuffer(relativeOffsets2, index: 8)
    #else
    commandList.setDescriptor(
      handleID: motionVectorsHandleID, index: 5)
    commandList.setDescriptor(
      handleID: addressOccupiedMarksHandleID, index: 6)
    commandList.setDescriptor(
      handleID: relativeOffsets1HandleID, index: 7)
    commandList.setDescriptor(
      handleID: relativeOffsets2HandleID, index: 8)
    #endif
  }
}

struct BVHBuilderDescriptor {
  var addressSpaceSize: Int?
  var device: Device?
  var voxelAllocationSize: Int?
  var worldDimension: Int?
}

class BVHBuilder {
  let addressSpaceSize: Int
  
  // Per atom address
  let atoms: Buffer
  let motionVectors: Buffer
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
  
  // Small counters and bookkeeping
  let crashBuffer: CrashBuffer
  
  // Per dense voxel
  
  init(descriptor: BVHBuilderDescriptor) {
    guard let addressSpaceSize = descriptor.addressSpaceSize,
          let device = descriptor.device,
          let voxelAllocationSize = descriptor.voxelAllocationSize,
          let worldDimension = descriptor.worldDimension else {
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
    
    var crashBufferDesc = CrashBufferDescriptor()
    crashBufferDesc.device = device
    crashBufferDesc.size = 1024
    self.crashBuffer = CrashBuffer(descriptor: crashBufferDesc)
    
    /*
     // Data buffers (per cell).
     let largeVoxelCount = 128 * 128 * 128
     let cellGroupCount = largeVoxelCount / (4 * 4 * 4)
     cellGroupMarks = createBuffer(length: cellGroupCount)
     largeCounterMetadata = createBuffer(length: largeVoxelCount * 8 * 4)
     largeCellOffsets = createBuffer(length: largeVoxelCount * 4)
     */
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

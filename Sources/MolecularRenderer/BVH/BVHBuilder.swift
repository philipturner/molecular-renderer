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
  
  init(descriptor: BVHBuilderDescriptor) {
    guard let addressSpaceSize = descriptor.addressSpaceSize,
          let device = descriptor.device,
          let voxelAllocationSize = descriptor.voxelAllocationSize,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }
    self.addressSpaceSize = addressSpaceSize
    
    self.atoms = Self.createAtomsBuffer(
      device: device, addressSpaceSize: addressSpaceSize)
    self.motionVectors = Self.createMotionVectorsBuffer(
      device: device, addressSpaceSize: addressSpaceSize)
    self.relativeOffsets1 = Self.createRelativeOffsetsBuffer(
      device: device, addressSpaceSize: addressSpaceSize)
    self.relativeOffsets2 = Self.createRelativeOffsetsBuffer(
      device: device, addressSpaceSize: addressSpaceSize)
  }
  
  private static func createAtomsBuffer(
    device: Device,
    addressSpaceSize: Int
  ) -> Buffer {
    var bufferDesc = BufferDescriptor()
    bufferDesc.device = device
    bufferDesc.size = addressSpaceSize * 16
    bufferDesc.type = .native(.device)
    return Buffer(descriptor: bufferDesc)
  }
  
  private static func createMotionVectorsBuffer(
    device: Device,
    addressSpaceSize: Int
  ) -> Buffer {
    var bufferDesc = BufferDescriptor()
    bufferDesc.device = device
    bufferDesc.size = addressSpaceSize * 8
    bufferDesc.type = .native(.device)
    return Buffer(descriptor: bufferDesc)
  }
  
  private static func createRelativeOffsetsBuffer(
    device: Device,
    addressSpaceSize: Int
  ) -> Buffer {
    var bufferDesc = BufferDescriptor()
    bufferDesc.device = device
    bufferDesc.size = addressSpaceSize * 8
    bufferDesc.type = .native(.device)
    return Buffer(descriptor: bufferDesc)
  }
}

struct VoxelResourcesDescriptor {
  var device: Device?
  var voxelAllocationSize: Int?
  var worldDimension: Int?
}

class VoxelResources {
  let worldDimension: Int
  
  // Per dense voxel
  let voxelGroupMarks: Buffer
  let atomicCounters: Buffer
  let memorySlotIDs: Buffer // TODO: initialize to UInt32.max once at startup
  
  // Per sparse voxel
  
  init(descriptor: VoxelResourcesDescriptor) {
    guard let device = descriptor.device,
          let voxelAllocationSize = descriptor.voxelAllocationSize,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Create a general purpose buffer that resides natively on the GPU.
    func createBuffer(size: Int) -> Buffer {
      var bufferDesc = BufferDescriptor()
      bufferDesc.device = device
      bufferDesc.size = size
      bufferDesc.type = .native(.device)
      return Buffer(descriptor: bufferDesc)
    }
    
    // Create the per dense voxel resources.
    guard worldDimension % (8 * 4) == 0 else {
      fatalError("World dimension was not divisible by 32.")
    }
    guard worldDimension > 0 else {
      fatalError("World dimension was zero.")
    }
    self.worldDimension = worldDimension
    
    let voxelGroupCount = Self.voxelGroupCount(worldDimension: worldDimension)
    let voxelCount = Self.voxelCount(worldDimension: worldDimension)
    self.voxelGroupMarks = createBuffer(size: voxelGroupCount * 4)
    self.atomicCounters = createBuffer(size: voxelCount * 32)
    self.memorySlotIDs = createBuffer(size: voxelCount * 4)
    
    print("voxel group count:", voxelGroupCount)
    print("voxel count:", voxelCount)
  }
  
  static func voxelGroupCount(worldDimension: Int) -> Int {
    var output: Int = 1
    output *= worldDimension / 8
    output *= worldDimension / 8
    output *= worldDimension / 8
    return output
  }
  
  static func voxelCount(worldDimension: Int) -> Int {
    var output: Int = 1
    output *= worldDimension / 2
    output *= worldDimension / 2
    output *= worldDimension / 2
    return output
  }
}

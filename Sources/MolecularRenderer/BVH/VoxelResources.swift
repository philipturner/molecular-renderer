struct VoxelResourcesDescriptor {
  var device: Device?
  var voxelAllocationSize: Int?
  var worldDimension: Int?
}

class VoxelResources {
  let worldDimension: Int
  let memorySlotCount: Int
  
  // Per dense voxel
  let voxelGroupMarks: Buffer // purge to 0 every frame
  let atomicCounters: Buffer // initialize to 0 with shader
                             // purge occupied voxels to 0 with idle/active
  let memorySlotIDs: Buffer // initialize to UInt32.max with shader
  
  // Per sparse voxel
  let assignedVoxelIDs: Buffer // initialize to UInt32.max with shader
  let vacantSlotIDs: Buffer // purge to UInt32.max before every frame
  let memorySlots: Buffer
  
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
    
    // Create the per sparse voxel resources.
    self.memorySlotCount = Self.memorySlotCount(
      voxelAllocationSize: voxelAllocationSize)
    guard memorySlotCount > 0 else {
      fatalError("Memory slot count was zero.")
    }
    
    self.assignedVoxelIDs = createBuffer(size: memorySlotCount * 4)
    self.vacantSlotIDs = createBuffer(size: memorySlotCount * 4)
    self.memorySlots = createBuffer(size: memorySlotCount * Self.memorySlotSize)
    
    print("voxel group count:", voxelGroupCount)
    print("voxel count:", voxelCount)
    print("memory slot size:", Self.memorySlotSize)
    print("memory slot count:", memorySlotCount)
    print("voxel allocation size:", memorySlots.size)
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
  
  static func memorySlotCount(voxelAllocationSize: Int) -> Int {
    return voxelAllocationSize / memorySlotSize
  }
  
  static var memorySlotSize: Int {
    var output: Int = .zero
    output += 16 // header
    output += 512 * 8 // per 0.25 nm voxel header
    output += 3072 * 4 // 2 nm -> global mapping, fused with 3-bit tag
    output += 20480 * 4 // 0.25 nm -> global mapping
    return output
  }
}

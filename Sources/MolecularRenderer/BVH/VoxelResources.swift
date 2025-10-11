struct VoxelResourcesDescriptor {
  var device: Device?
  var voxelAllocationSize: Int?
  var worldDimension: Float?
}

class VoxelResources {
  let worldDimension: Float
  let memorySlotCount: Int
  
  // Per dense voxel
  let voxelGroupAddedMarks: Buffer // purge to 0 every frame
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
    guard worldDimension.remainder(dividingBy: 8) == 0 else {
      fatalError("World dimension was not divisible by 8.")
    }
    guard worldDimension > 0 else {
      fatalError("World dimension was zero.")
    }
    self.worldDimension = worldDimension
    
    let voxelGroupCount = Self.voxelGroupCount(worldDimension: worldDimension)
    let voxelCount = Self.voxelCount(worldDimension: worldDimension)
    self.voxelGroupAddedMarks = createBuffer(size: voxelGroupCount * 4)
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
  }
  
  static func voxelGroupCount(worldDimension: Float) -> Int {
    var output: Int = 1
    for _ in 0..<3 {
      output *= Int(worldDimension / 8)
    }
    return output
  }
  
  static func voxelCount(worldDimension: Float) -> Int {
    var output: Int = 1
    for _ in 0..<3 {
      output *= Int(worldDimension / 2)
    }
    return output
  }
  
  // Shader code to generate a voxel address.
  static func generate(
    _ input: String,
    _ gridDimension: Float
  ) -> String {
    let gridWidthSq = Int(gridDimension * gridDimension)
    let gridWidth = Int(gridDimension)
    return "\(input).z * \(gridWidthSq) + \(input).y * \(gridWidth) + \(input).x"
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

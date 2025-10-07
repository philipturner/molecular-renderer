struct BVHBuilderDescriptor {
  var addressSpaceSize: Int?
  var device: Device?
  var voxelAllocationSize: Int?
  var worldDimension: Int?
}

class BVHBuilder {
  let atomResources: AtomResources
  
  // Small counters and bookkeeping
  let crashBuffer: CrashBuffer
  
  // Per dense voxel
  
  // Per sparse voxel
  
  init(descriptor: BVHBuilderDescriptor) {
    guard let addressSpaceSize = descriptor.addressSpaceSize,
          let device = descriptor.device,
          let voxelAllocationSize = descriptor.voxelAllocationSize,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }
    
    var atomResourcesDesc = AtomResourcesDescriptor()
    
    var crashBufferDesc = CrashBufferDescriptor()
    crashBufferDesc.device = device
    crashBufferDesc.size = 1024
    self.crashBuffer = CrashBuffer(descriptor: crashBufferDesc)
    
    // check that world dimension is divisible by 8 * 4
    // check that world dimension is greater than 0
    
    /*
     // Data buffers (per cell).
     let largeVoxelCount = 128 * 128 * 128
     let cellGroupCount = largeVoxelCount / (4 * 4 * 4)
     cellGroupMarks = createBuffer(length: cellGroupCount)
     largeCounterMetadata = createBuffer(length: largeVoxelCount * 8 * 4)
     largeCellOffsets = createBuffer(length: largeVoxelCount * 4)
     */
  }
}

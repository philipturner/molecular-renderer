struct VoxelResourcesDescriptor {
  var device: Device?
  var voxelAllocationSize: Int?
  var worldDimension: Int?
}

class VoxelResources {
  // Per dense voxel
  
  // Per sparse voxel
  
  init(descriptor: VoxelResourcesDescriptor) {
    guard let device = descriptor.device,
          let voxelAllocationSize = descriptor.voxelAllocationSize,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Create the per dense voxel resources.
    guard worldDimension % (8 * 4) == 0 else {
      fatalError("World dimension was not divisible by 32.")
    }
    guard worldDimension > 0 else {
      fatalError("World dimension was zero.")
    }
  }
}

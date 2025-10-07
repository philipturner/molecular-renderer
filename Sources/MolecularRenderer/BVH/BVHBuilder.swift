struct BVHDescriptor {
  var addressSpaceSize: Int?
  var device: Device?
  var voxelAllocationSize: Int?
  var worldDimension: Int?
}

class BVH {
  init(descriptor: BVHDescriptor) {
    guard let addressSpaceSize = descriptor.addressSpaceSize,
          
          let voxelAllocationSize = descriptor.voxelAllocationSize,
          let worldDimension = descriptor.worldDimension else {
      
    }
  }
}

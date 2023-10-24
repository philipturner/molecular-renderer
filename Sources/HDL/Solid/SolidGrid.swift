//
//  Grid.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/24/23.
//

import Foundation

// New, sparse internal representation:
// - lower octants: 0.25 nm
// - lower voxels: 0.5 nm
// - upper voxels: 2.0 nm
//
// - store chunks of 8 atoms in the arrays, interlacing atoms for each octant
//   - [SIMD8(x0), SIMD8(y0), SIMD8(z0), SIMD8(x1), SIMD8(y1), SIMD8(z1), ...]
// - when merging, sort the incoming atoms into the existing octants
// - perform 8 comparisons in parallel, lanewise, instead of 64 un-sorted
// - no restrictions on atom density
//
// `Solid` objects should retain ownership of the grid that created them. Use
// that grid instead of a raw list of atoms, as it contains some very useful
// structure. For example, it could be used to easily sort the atoms into Morton
// order at an extremely high resolution (with connected hydrogens/halogens
// simply inserted into the list). It would also be critical for accelerating
// `Solid` + `Solid` merge operations.
//
// A little bit of the foundation is already here, such as means for exporting
// in Morton order. However, that should be relocated to RigidBody or some other
// file.
//
// Algorithms:
// - Verify integrity of unknown atom source, throwing error if atoms are duplicated
// - Scan 8 closest octants during the comparison, use old atom’s position and new atom’s identity
//     - round to nearest even when finding search octant
//     - If within floating point epsilon away from 2 planes of first matching octant, set lane mask to 1 octant in that direction
//     - If other octant is out of bounds, set lane mask to 1 octant and potentially modify the lower search corner
// - Otherwise, enter memory allocation pass
// - Check for overlapping destination octants in the incoming atom 8-vector, special serial case to handle what happens (match count > 1 and address not -1)

struct SolidLowerVoxel {
  /// Each vector lane corresponds to a potentially present element from one of
  /// the 8 octants. This is a highly efficient method to store the data
  /// pre-sorted into octants. Entity block x/y/z are absolute positions, not
  /// positions relative to the lower corner.
  var entities: [EntityBlock] = [EntityBlock()]
  
  /// Stores the number of non-empty atoms in each octant. Will never exceed 255.
  var octantCounts: SIMD8<UInt8> = .zero
}

struct SolidUpperVoxel {
  /// Stores a 4x4x4 grid of lower voxels.
  var lowerVoxels: [SolidLowerVoxel] = Array(repeating: .init(), count: 64)
}

struct SolidGrid {
  /// This must always be divisible by 2.
  var lowerBound: SIMD3<Float>
  
  /// This must always be divisible by 2.
  var upperBound: SIMD3<Float>
  
  /// Coordinates used for addressing upper voxels.
  var upperDimensions: SIMD3<Int32>
  
  /// Two-level sparse grid of upper voxels.
  var upperVoxels: [SolidUpperVoxel?]
  
  init(lowerBound: SIMD3<Float>, upperBound: SIMD3<Float>) {
    // Pad the bounds to a multiple of upper voxel size.
    self.lowerBound = (lowerBound / 2.0).rounded(.down) * 2.0
    self.upperBound = (upperBound / 2.0).rounded(.up) * 2.0
    
    let dimensions = upperBound - lowerBound
    self.upperDimensions = SIMD3<Int32>((dimensions / 2.0).rounded(.up))
    
    let voxelCount = upperDimensions.x * upperDimensions.y * upperDimensions.z
    self.upperVoxels = Array(repeating: nil, count: Int(voxelCount))
  }
  
  /// - Parameter other: The old grid to expand.
  /// - Parameter offset: Where `other` should start in the new grid.
  init(
    lowerBound: SIMD3<Float>,
    upperBound: SIMD3<Float>,
    expanding other: SolidGrid
  ) {
    self.init(lowerBound: lowerBound, upperBound: upperBound)
    guard all(self.lowerBound .<= other.lowerBound),
          all(self.upperBound .>= other.upperBound) else {
      fatalError("Tried to expand a grid into a smaller volume.")
    }
    
    for oldZ in 0..<other.upperDimensions.z {
      for oldY in 0..<other.upperDimensions.y {
        for oldX in 0..<other.upperDimensions.x {
          let oldUpperPosition = SIMD3(oldX, oldY, oldZ)
          let oldRelativePosition = SIMD3<Float>(oldUpperPosition) * 2.0
          let absolutePosition = other.lowerBound + oldRelativePosition
          let newRelativePosition = absolutePosition - self.lowerBound
          let newUpperPosition = SIMD3<Int32>(newRelativePosition / 2.0)
          let newX = newUpperPosition.x
          let newY = newUpperPosition.y
          let newZ = newUpperPosition.z
          
          var oldUpperAddress = oldZ &* other.upperDimensions.y &+ oldY
          var newUpperAddress = newZ &* self.upperDimensions.y &+ newY
          oldUpperAddress = oldUpperAddress &* other.upperDimensions.x &+ oldX
          newUpperAddress = newUpperAddress &* self.upperDimensions.x &+ newX
          let upperVoxel = other.upperVoxels[Int(oldUpperAddress)]
          self.upperVoxels[Int(newUpperAddress)] = upperVoxel
        }
      }
    }
  }
  
  /// Create a new grid while verifying integrity of the data source.
  init(entities: [Entity]) {
    var lowerBound = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var upperBound = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
    for entity in entities where !entity.isEmpty {
      lowerBound.replace(
        with: entity.position, where: entity.position .< lowerBound)
      upperBound.replace(
        with: entity.position, where: entity.position .> upperBound)
    }
    if entities.count == 0 {
      lowerBound = .zero
      upperBound = .zero
    }
    self.init(lowerBound: lowerBound, upperBound: upperBound)
    
    // Run through the loop in groups of 8 entities.
    let blockCount = (entities.count + 7) / 8
    for blockID in 0..<blockCount {
      var block = EntityBlock()
      let blockStart = blockID * 8
      
      if blockID * 8 + 7 < entities.count {
        for lane in 0..<8 {
          let entity = entities[blockStart + lane]
          block.x[lane] = entity.storage.x
          block.y[lane] = entity.storage.y
          block.z[lane] = entity.storage.z
          block.w[lane] = entity.storage.w
        }
      } else {
        for lane in 0..<entities.count - blockStart {
          let entity = entities[blockStart + lane]
          block.x[lane] = entity.storage.x
          block.y[lane] = entity.storage.y
          block.z[lane] = entity.storage.z
          block.w[lane] = entity.storage.w
        }
      }
      
      // TODO: Finish
    }
  }
}

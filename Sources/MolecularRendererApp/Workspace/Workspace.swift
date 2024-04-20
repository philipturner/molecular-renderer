import Foundation
import HDL
import MM4
import Numerics
import OpenMM

fileprivate typealias HousingBounds = (minimum: SIMD3<Float>, maximum: SIMD3<Float>)
fileprivate func createBounds(rods: [Rod]) -> HousingBounds {
  var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
  var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
  for rod in rods {
    let volume = rod.createExcludedVolume(padding: 2)
    minimum.replace(with: volume.minimum, where: volume.minimum .< minimum)
    maximum.replace(with: volume.maximum, where: volume.maximum .> maximum)
  }
  return (minimum, maximum)
}

func createGeometry() -> [Entity] {
  let cla = CLA()
  
  // Round up to allocate voxels.
  var (minimum, maximum) = createBounds(rods: cla.rods)
  minimum.round(.down)
  maximum.round(.up)
  print(minimum)
  print(maximum)
  print(cla.rods.reduce(0) { $0 + $1.rigidBody.parameters.atoms.count })
  
  // MARK: - Patterns
  
  var holePatterns: [HolePattern] = []
  var housingPatterns: [HolePattern] = []
  for rod in cla.rods {
    var volume = rod.createExcludedVolume(padding: 0)
    volume.minimum -= SIMD3<Float>(minimum)
    volume.maximum -= SIMD3<Float>(minimum)
    
    holePatterns.append { h, k, l in
      Concave {
        Concave {
          Origin { volume.minimum * (h + k + l) }
          Plane { h }
          Plane { k }
          Plane { l }
        }
        Concave {
          Origin { volume.maximum * (h + k + l) }
          Plane { -h }
          Plane { -k }
          Plane { -l }
        }
      }
      Replace { .empty }
    }
  }
  
  for rod in cla.rods {
    var volume = rod.createExcludedVolume(padding: 5)
    volume.minimum -= SIMD3<Float>(minimum)
    volume.maximum -= SIMD3<Float>(minimum)
    
    housingPatterns.append { h, k, l in
      Convex {
        Convex {
          Origin { volume.minimum * (h + k + l) }
          Plane { -h }
          Plane { -k }
          Plane { -l }
        }
        Convex {
          Origin { volume.maximum * (h + k + l) }
          Plane { h }
          Plane { k }
          Plane { l }
        }
      }
    }
  }
  
  // MARK: - Housing
  
  var housingDesc = LogicHousingDescriptor()
  housingDesc.dimensions = SIMD3(maximum - minimum)
  housingDesc.patterns = holePatterns
  housingDesc.patterns.append { h, k, l in
    Concave {
      for pattern in housingPatterns {
        Convex {
          pattern(h, k, l)
        }
      }
    }
    Replace { .empty }
  }
  
  var unitRodsArray: [[Rod]] = []
  unitRodsArray.append(cla.inputUnit.rods)
  unitRodsArray.append(cla.generateUnit.rods)
  unitRodsArray.append(cla.propagateUnit.rods)
  unitRodsArray.append(cla.carryUnit.rods)
  unitRodsArray.append(cla.outputUnit.rods)
  
  // Trim the housing to the actual minimum and maximum.
  var boundsPatterns: [HolePattern] = []
  for unitRodsGroupID in unitRodsArray.indices {
    let unitRodsGroup = unitRodsArray[unitRodsGroupID]
    
    var bounds: HousingBounds = createBounds(rods: unitRodsGroup)
    if unitRodsGroupID == 4 {
      bounds.maximum.z += 5
    }
    
    let boundsPattern: HolePattern = { h, k, l in
      Convex {
        Convex {
          Origin { (bounds.0 - minimum) * (h + k + l) }
          Plane { -h }
          Plane { -k }
          Plane { -l }
        }
        Convex {
          Origin { (bounds.1 - minimum) * (h + k + l) }
          Plane { h }
          Plane { l }
        }
      }
    }
    boundsPatterns.append(boundsPattern)
  }
  housingDesc.patterns.append { h, k, l in
    Concave {
      for pattern in boundsPatterns {
        Convex {
          pattern(h, k, l)
        }
      }
    }
    Replace { .empty }
  }
  
  let housing = LogicHousing(descriptor: housingDesc)
  print(housing.topology.atoms.count)
  
  return housing.topology.atoms
}

//
//  CLA.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/19/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct CLA {
  var inputUnit = CLAInputUnit()
  var generateUnit = CLAGenerateUnit()
  var propagateUnit = CLAPropagateUnit()
  var carryUnit = CLACarryUnit()
  var outputUnit = CLAOutputUnit()
  
  var rods: [Rod] {
    inputUnit.rods +
    generateUnit.rods +
    propagateUnit.rods +
    carryUnit.rods +
    outputUnit.rods
  }
  
  init() {
    
  }
  
  func createHousingDescriptor() -> LogicHousingDescriptor {
    // Round up to allocate voxels.
    var (minimum, maximum) = createBounds(rods: rods)
    minimum.round(.down)
    maximum.round(.up)
    
    // MARK: - Patterns
    
    var holePatterns: [HolePattern] = []
    var housingPatterns: [HolePattern] = []
    for rod in rods {
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
    
    func addVolume(_ originalVolume: HousingBounds) {
      var volume = originalVolume
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
    
    for rod in rods {
      var volume = rod.createExcludedVolume(padding: 4)
      addVolume(volume)
    }
    for rod in Array(propagateUnit.broadcast.values) {
      var volume = rod.createExcludedVolume(padding: 4)
      volume.minimum.x -= 2
      addVolume(volume)
    }
    for rod in Array(carryUnit.rods) {
      var volume = rod.createExcludedVolume(padding: 4)
      volume.maximum.x += 4
      addVolume(volume)
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
    
    // Trim the housing to the actual minimum and maximum.
    let volumes = createUnitVolumes()
    var boundsPatterns: [HolePattern] = []
    for bounds in volumes {
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
    
    return housingDesc
  }
  
  private func createUnitVolumes() -> [HousingBounds] {
    var unitRodsArray: [[Rod]] = []
    unitRodsArray.append(inputUnit.rods)
    unitRodsArray.append(generateUnit.rods)
    unitRodsArray.append(propagateUnit.rods)
    unitRodsArray.append(carryUnit.rods)
    unitRodsArray.append(outputUnit.rods)
    
    var volumes: [HousingBounds] = []
    for unitRodsGroup in unitRodsArray {
      let bounds = createBounds(rods: unitRodsGroup)
      volumes.append(bounds)
    }
//    volumes[1].maximum.x -= 2
//    volumes[2].maximum.x -= 2
    volumes[3].minimum.x -= 2
    volumes[3].maximum.x += 2
    return volumes
  }
}

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

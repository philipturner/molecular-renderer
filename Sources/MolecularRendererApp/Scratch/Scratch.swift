// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // Demonstrate transmission of a clock signal in one of the 2 available
  // directions. It should demonstrate the sequence of clock phases expected in
  // the full ALU. Measure how short the switching time can be.
  let housingLattice = Lattice<Cubic> { h, k, l in
    Bounds { 16 * h + 20 * k + 8 * l }
    Material { .elemental(.carbon) }
    
    func createRodVolume(xIndex: Int, yIndex: Int) {
      Origin { 8 * Float(xIndex) * h }
      Origin { 10 * Float(yIndex) * k }
      Origin { 4 * h + 3.5 * k }
      
      var loopDirections: [SIMD3<Float>] = []
      loopDirections.append(h)
      loopDirections.append(k)
      loopDirections.append(-h)
      loopDirections.append(-k)
      
      Concave {
        for i in 0..<4 {
          Convex {
            Origin { 2 * loopDirections[i] }
            if i == 1 {
              Origin { 0.25 * k }
            }
            Plane { -loopDirections[i] }
          }
          Convex {
            let current = loopDirections[i]
            let next = loopDirections[(i + 1) % 4]
            Origin { (current + next) * 1.75 }
            if i == 0 || i == 1 {
              Origin { 0.25 * k }
            }
            Plane { (current + next) * -1 }
          }
        }
      }
    }
    
    Volume {
      for xIndex in 0..<2 {
        for yIndex in 0..<2 {
          Convex {
            createRodVolume(xIndex: xIndex, yIndex: yIndex)
          }
        }
      }
      
      Replace { .empty }
    }
  }
  
  let rodLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    let length: Float = 20
    Bounds { length * h + 2 * h2k + 4 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Convex {
        Origin { 1.9 * l }
        Plane { l }
      }
      Convex {
        Origin { 1 * h2k }
        Plane { k - h }
      }
      Replace { .empty }
    }
  }
  
  var output: [Entity] = []
  output.append(contentsOf: housingLattice.atoms)
  
  let diamondConstant = Constant(.square) { .elemental(.carbon) }
  var rodAtoms = rodLattice.atoms
  for i in rodAtoms.indices {
    var position = rodAtoms[i].position
    position = SIMD3(position.z, position.y, position.x)
    position += diamondConstant * SIMD3(3.0, 2.5, 0)
    position.x += 0.030
    position.y -= 0.050
    rodAtoms[i].position = position
  }
  for xIndex in 0..<2 {
    for yIndex in 0..<2 {
      var currentRodAtoms = rodAtoms
      for i in currentRodAtoms.indices {
        var position = currentRodAtoms[i].position
        position.x += 8 * diamondConstant * Float(xIndex)
        position.y += 10 * diamondConstant * Float(yIndex)
        currentRodAtoms[i].position = position
      }
      output.append(contentsOf: currentRodAtoms)
    }
  }
  
  let driveWallLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 4 * h + 17 * h2k + 14 * l }
    Material { .checkerboard(.silicon, .carbon) }
    
    for xIndex in 0..<2 {
      for yIndex in 0..<2 {
        Volume {
          if xIndex == 0 {
            Origin { 2.5 * l }
          } else {
            Origin { 8 * l }
          }
          if yIndex == 0 {
            Origin { 2.5 * h2k }
          } else {
            Origin { 9.5 * h2k }
          }
          
          Concave {
            Origin { 1.9 * h }
            Plane { h }
            
            Convex {
              Origin { -0.1 * l }
              Plane { l }
            }
            Plane { h2k }
            Origin { 3.5 * l }
            
            // Coupled with the origin for h2k.
            if yIndex == 0 {
              Origin { 2.5 * h2k }
            } else {
              Origin { 2.25 * h2k }
            }
            Plane { -l }
            Plane { -k + h }
          }
          
          Replace { .empty }
        }
      }
    }
  }
  
  let moissaniteHexagonConstant = Constant(.hexagon) {
    .checkerboard(.silicon, .carbon)
  }
  let moissanitePrismConstant = Constant(.prism) {
    .checkerboard(.silicon, .carbon)
  }
  var driveWallAtoms = driveWallLattice.atoms
  for i in driveWallAtoms.indices {
    var position = driveWallAtoms[i].position
    position = SIMD3(position.z, position.y, position.x)
    position.x += -1 * moissanitePrismConstant
    position.y += -3.25 * moissaniteHexagonConstant
    position.z += -6 * moissaniteHexagonConstant
    driveWallAtoms[i].position = position
  }
  output.append(contentsOf: driveWallAtoms)
  
  return output
}

// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MolecularRenderer
import Numerics

func createNanomachinery() -> [MRAtom] {
  // The entire assembly can be roughly put together, even while many
  // important pieces are missing. This should be done to get a rough
  // estimate of the atom count and final geometry.
  //
  // missing pieces:
  // - level 1:
  //   - small manufactured pieces (gold atoms)
  //   - gold atom floating inside each robot arm
  //
  // - level 2:
  //   - new crystolecule building clock that forms chains
  //   - rod that links controls for 3 assembly lines in SIMD fashion
  //   - leave some space near the rods, to visualize the adjacent quadrant
  //   - larger manufactured pieces (gold atoms)
  
  // MARK: - Assembly Machinery
  
  let masterQuadrant = Quadrant()
  var quadrants: [Quadrant] = []
  quadrants.append(masterQuadrant)
  
  let constructFullScene = Bool.random() ? false : false
  
  if constructFullScene {
    for i in 1..<4 {
      let angle = Float(i) * -90 * .pi / 180
      let quaternion = Quaternion<Float>(angle: angle, axis: [0, 1, 0])
      let basisX = quaternion.act(on: [1, 0, 0])
      let basisY = quaternion.act(on: [0, 1, 0])
      let basisZ = quaternion.act(on: [0, 0, 1])
      quadrants.append(masterQuadrant)
      quadrants[i].transform {
        var origin = $0.origin.x * basisX
        origin.addProduct($0.origin.y, basisY)
        origin.addProduct($0.origin.z, basisZ)
        $0.origin = origin
      }
    }
  }
  for i in quadrants.indices {
    quadrants[i].transform { $0.origin.y += 23.5 }
  }
  
  if constructFullScene {
    for i in quadrants.indices {
      var copy = quadrants[i]
      copy.transform { $0.origin.y *= -1 }
      quadrants.append(copy)
    }
  }
  var output = quadrants.flatMap { $0.createAtoms() }
  
  if constructFullScene {
    let floor = Floor(openCenter: true)
    output += floor.createAtoms()
  }
  
  // MARK: - Scratch
  
  let rodLattice = createBroadcastRod()

  #if false
  // More robust path copying atoms and translating.
  var rodAtoms = rodLattice.entities.map(MRAtom.init)
  for i in rodAtoms.indices {
    rodAtoms[i].origin += SIMD3(-71.75, 30.75, -21)
  }
  output += rodAtoms
  #else
  // Alternative path using Diamondoid and rotating.
  var rod = Diamondoid(lattice: rodLattice)
  rod.setCenterOfMass(.zero)
  let rodBox = rod.createBoundingBox()
  rod.translate(offset: [
    -61.9 - rodBox.0.x,
     30.55 - rodBox.0.y,
     -20.3 - rodBox.0.z
  ])
  output += rod.atoms
  #endif
  
  return output
}

func createBroadcastRod() -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 284 * h + 10 * h2k + 2 * l }
    Material { .elemental(.carbon) }
    
    func createCutPair() {
      Concave {
        Convex {
          Origin { 3 * h }
          Plane { -k }
        }
        Convex {
          Origin { 3 * h2k }
          Plane { -h2k }
        }
        Convex {
          Origin { 69 * h }
          Plane { -k - h }
        }
      }
      
      Concave {
        Origin { 5 * h2k }
        Convex {
          Origin { -12 * h }
          Plane { k + h }
        }
        Convex {
          Origin { -3 * h2k }
          Plane { h2k }
        }
        Convex {
          Origin { 12 * h }
          Plane { k }
        }
      }
    }
    
    Volume {
      Convex {
        Origin { 5 * h2k }
        Plane { h2k }
      }
      Convex {
        Origin { 40 * h }
        Plane { -h }
      }
      
      for index in 0..<5 {
        Convex {
          Origin { -20 * h }
          Origin { Float(index) * 72 * h }
          createCutPair()
        }
      }
      
      
      
      Replace { .empty }
    }
  }
}

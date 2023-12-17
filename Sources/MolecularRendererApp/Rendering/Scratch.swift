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
  
  let beltLinkLattice = createBeltLink()
  var beltLinkDiamondoid = Diamondoid(lattice: beltLinkLattice)
  output += beltLinkDiamondoid.atoms
  
  beltLinkDiamondoid.translate(offset: [3.8, 0, 0])
  output += beltLinkDiamondoid.atoms
  
  // Prototype the belt in front of the quadrant, with an easy method to
  // transfer it to the right side. This provides both a visually easy method
  // to connect the h/k planes to geometry and a double-checker against where it
  // will actually be placed.
  
  
  return output
}


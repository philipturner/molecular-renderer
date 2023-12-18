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
  //   - built plates + 1st-step products
  
  // MARK: - Assembly Machinery
  
  let masterQuadrant = Quadrant()
  var quadrants: [Quadrant] = []
  quadrants.append(masterQuadrant)
  
  let constructFullScene = Bool.random() ? true : true
  
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
    output += floor.createAtoms().map {
      var copy = $0
      copy.origin = SIMD3(-copy.origin.z, copy.origin.y, copy.origin.x)
      return copy
    }
  }
  
  let arm = ServoArm()
  output += arm.createAtoms()
  
  // MARK: - Scratch
  
//  var output: [MRAtom] = []
  
  return output
  
//  let product: [MRAtom] = createBeltLinkProduct()
//  return createBuildPlate(product: product, sideHydrogens: false)
}

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
  let beltLinkAtoms = beltLinkLattice.entities.map(MRAtom.init)
  output += beltLinkAtoms
  
  // Prototype the belt in front of the quadrant, with an easy method to
  // transfer it to the right side. This providees both a visually easy method
  // to connect the h/k planes to geometry and a double-checker against where it
  // will actually be placed.
  
  
  return output
}

func createBeltLink() -> Lattice<Hexagonal> {
  // One encounter mechanism is 4 nm x 4 nm x 2 nm in Nanosystems 13.3.5(a).
  // 16 = 4 / Constant(.hexagon) { .elemental(.carbon) }
  //  5 = 2 / Float(3).squareRoot() / Constant(.hexagon) { .elemental(.carbon) }
  // 10 = 4 / Constant(.prism) { .elemental(.carbon) }
  
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 20 * h + 5 * h2k + 12 * l }
    Material { .elemental(.carbon) }
    
    func createEncounterVolume() {
      Convex {
        Plane { -h }
        Plane { -h2k }
        Plane { -l }
        Origin  { 16 * h + 5 * h2k + 9.75 * l }
        Plane { h }
        Plane { h2k }
        Plane { l }
      }
    }
    
    // Hook and knob-style connectors. The hook protrudes from the current
    // object and latches onto the opposite side of the adjacent object. There
    // should be enough breathing room for the belt to be inclined at a slight
    // angle.
    Volume {
      Concave {
        Convex {
          Origin { 2 * h2k }
          Plane { h2k }
        }
        Convex {
          Origin { 2 * h + 1 * l }
          createEncounterVolume()
        }
      }
      Replace { .empty }
    }
  }
}

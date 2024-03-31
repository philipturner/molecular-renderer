import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// WARNING: The renderer could be in 'MRSceneSize.extreme'. If so, it will not
// render any animations.
func createGeometry() -> [Entity] {
  // TODO: Design a new drive wall for the rods, based on the revised design
  // constraints. Get it tested on the AMD GPU before continuing with
  // patterning the logic rods.
  
  // Compile the geometry.
  let testRod = TestRod()
  let driveWallLattice = Lattice<Cubic> { h, k, l in
    Bounds { 10 * h + 6 * k + 10 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Plane { h - k }
      Replace { .empty }
    }
  }
  
  // Render the scene.
  var atoms: [Entity] = []
  atoms += testRod.topology.atoms.map {
    var copy = $0
    copy.position.z += 0.5
    copy.position.x += 1
    return copy
  }
  atoms += testRod.topology.atoms.map {
    var copy = $0
    copy.position.z += 2.5
    copy.position.x += 2
    copy.position.y += 1
    return copy
  }
  atoms += driveWallLattice.atoms
  return atoms
}

struct TestRod {
  var topology = Topology()
  
  init() {
    createLattice()
    createSulfurAtoms()
    removeSulfurMarkers()
  }
  
  mutating func createLattice() {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 20 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Concave {
          Concave {
            Origin { 1 * h2k }
            Plane { h2k }
            Origin { 1 * h }
            Plane { k - h }
          }
          Convex {
            Origin { 1.5 * h2k }
            Plane { h2k }
            Origin { 0.5 * h }
            Plane { -h }
          }
        }
        Replace { .empty }
      }
      Volume {
        Concave {
          Concave {
            Origin { 1 * h2k }
            Plane { h2k }
            Origin { 1 * h }
            Plane { k - h }
          }
        }
        Replace { .atom(.gold) }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  mutating func createSulfurAtoms() {
    // Locate the markers.
    var markerIndices: [UInt32] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      if atom.atomicNumber == 79 {
        markerIndices.append(UInt32(atomID))
      }
    }
    markerIndices.sort { atomID1, atomID2 in
      let atom1 = topology.atoms[Int(atomID1)]
      let atom2 = topology.atoms[Int(atomID2)]
      return atom1.position.z < atom2.position.z
    }
    guard markerIndices.count % 2 == 0 else {
      fatalError("Odd number of sulfur markers.")
    }
    
    // Add the sulfur atoms.
    var sulfurAtoms: [Entity] = []
    for pairID in 0..<4 {
      let markerID1 = markerIndices[pairID * 2 + 0]
      let markerID2 = markerIndices[pairID * 2 + 1]
      let atom1 = topology.atoms[Int(markerID1)]
      let atom2 = topology.atoms[Int(markerID2)]
      let position = (atom1.position + atom2.position) / 2
      
      let entity = Entity(position: position, type: .atom(.sulfur))
      sulfurAtoms.append(entity)
    }
    
    // Throw away the two sulfurs in the center.
    sulfurAtoms = [sulfurAtoms[0], sulfurAtoms[3]]
    topology.insert(atoms: sulfurAtoms)
  }
  
  mutating func removeSulfurMarkers() {
    var markerIndices: [UInt32] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      if atom.atomicNumber == 79 {
        markerIndices.append(UInt32(atomID))
      }
    }
    topology.remove(atoms: markerIndices)
  }
  
  mutating func passivate() {
    
  }
}

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  var part = RotaryPart()
  part.minimize(bulkAtomIDs: [])
  
  return [part.rigidBody]
}

struct RotaryPart: GenericPart {
  var rigidBody: MM4RigidBody
  
  init() {
    let lattice = Self.createLattice()
    let topology = Self.createTopology(lattice: lattice)
    rigidBody = Self.createRigidBody(topology: topology)
  }
  
  static func createLattice() -> Lattice<Hexagonal> {
    Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 41 * h + 4 * h2k + 4 * l }
      Material { .checkerboard(.germanium, .carbon) }
      
      Volume {
        Origin { 2 * h2k }
        Plane { -h2k }
        Replace { .empty }
      }
      Volume {
        Origin { 2.667 * h2k }
        Plane { -h2k }
        Replace { .atom(.carbon) }
      }
      Volume {
        Origin { 3.333 * h2k }
        Plane { h2k }
        Replace { .atom(.germanium) }
      }
    }
  }
  
  static func createTopology(lattice: Lattice<Hexagonal>) -> Topology {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .checkerboard(.germanium, .carbon)
    do {
      var atoms = lattice.atoms
      atoms.sort { $0.position.x < $1.position.x }
      reconstruction.topology.insert(atoms: atoms)
    }
    reconstruction.compile()
    reconstruction.topology.sort()
    var topology = reconstruction.topology
    
    // Parameters here are in nm.
    let latticeConstant = Constant(.hexagon) {
      .checkerboard(.germanium, .carbon)
    }
    
    // The X coordinate in the original space is mapped onto θ = (0, 2π).
    // - X = 0 transforms into θ = 0.
    // - X = 'perimeter' transforms into θ = 2π.
    // - Other values of X are mapped into the angular coordinate with a linear
    //   transformation. Anything outside of the range will overshoot and
    //   potentially overlap another chunk of matter.
    let perimeter = Float(40) * latticeConstant
    
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      var position = atom.position
      
      let θ = 2 * Float.pi * position.x / perimeter
      let r = position.y
      position.x = r * Float.cos(θ)
      position.y = r * Float.sin(θ)
      
      atom.position = position
      topology.atoms[atomID] = atom
    }
    
    topology = deduplicate(topology: topology)
    
    return topology
  }
}

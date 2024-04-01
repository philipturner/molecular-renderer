//
//  Flywheel.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/1/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct Flywheel {
  var rigidBody: MM4RigidBody
  
  init() {
    let lattice = Self.createLattice()
    let topology = Self.createTopology(lattice: lattice)
    rigidBody = Self.createRigidBody(topology: topology)
  }
  
  static func createLattice() -> Lattice<Hexagonal> {
    Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 120 * h + 6 * h2k + 3 * l }
      Material { .checkerboard(.germanium, .carbon) }
      
      Volume {
        Origin { 1.5 * h2k }
        Plane { -h2k }
        Replace { .atom(.carbon) }
      }
      Volume {
        Origin { 4 * h2k }
        Plane { h2k }
        Replace { .atom(.germanium) }
      }
    }
  }
  
  static func createTopology(lattice: Lattice<Hexagonal>) -> Topology {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .checkerboard(.germanium, .carbon)
    reconstruction.topology.insert(atoms: lattice.atoms)
    reconstruction.compile()
    
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
    let perimeter = Float(120 + 1) * latticeConstant
    
    // The distance between Y = 0 in the compiled lattice's coordinate space,
    // and the center of the warped circle.
    let curvatureRadius: Float = 5.0
    
    reconstruction.topology.sort()
    return reconstruction.topology
  }
  
  static func createRigidBody(topology: Topology) -> MM4RigidBody {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    return try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
}

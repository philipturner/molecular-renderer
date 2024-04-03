//
//  ConnectingRod.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/3/24.
//

import Foundation
import HDL
import MM4
import Numerics

// The 'connecting rod' component of a standard piston system.
// https://en.wikipedia.org/wiki/Connecting_rod
struct ConnectingRod {
  var rigidBody: MM4RigidBody
  
  init() {
    let lattice = Self.createLattice()
    let topology = Self.createTopology(lattice: lattice)
    rigidBody = Self.createRigidBody(topology: topology)
    rigidBody.centerOfMass.y = .zero
  }
  
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 35 * h + 6 * k + 3 * l }
      Material { .elemental(.carbon) }
      
      // chisel the corners to make them look more smooth
      //
      // add engraving 'nano' or 'nanotech'
      // perhaps use Ge dopants to form the pattern
      //
      // 00||0||00|0|||000|||000|0|||000|||0
      // ||||||||0||000|00000|00||000|0|000|
      // 0||00||00|0000|0|||||00|0000|0|000|
      // ||||||||0|0000|0|000|00|0000|0|000|
      // 0||0||000|0000|00|||0|0|0000|00|||0
    }
  }
  
  static func createTopology(lattice: Lattice<Cubic>) -> Topology {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.carbon)
    reconstruction.topology.insert(atoms: lattice.atoms)
    reconstruction.compile()
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

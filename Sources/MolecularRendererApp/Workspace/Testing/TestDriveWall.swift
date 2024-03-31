//
//  TestDriveWall.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/31/24.
//

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

struct TestDriveWall {
  var topology = Topology()
  var rigidBody: MM4RigidBody!
  
  init() {
    createLattice()
    passivate()
    createRigidBody()
  }
  
  mutating func createLattice() {
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 10 * h + 6 * k + 10 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Plane { h - k }
        Replace { .empty }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  
  // Add hydrogens and sort the atoms for efficient simulation.
  mutating func passivate() {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.carbon)
    reconstruction.topology = topology
    reconstruction.removePathologicalAtoms()
    reconstruction.createBulkAtomBonds()
    reconstruction.createHydrogenSites()
    reconstruction.resolveCollisions()
    reconstruction.createHydrogenBonds()
    topology = reconstruction.topology
    topology.sort()
  }
  
  mutating func createRigidBody() {
    // Create the MM4 parameters.
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    var parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    // Freeze the carbons ~2 atomic layers inside the bounding volume.
    let neighbors = topology.map(.atoms, to: .atoms)
    for atomID in topology.atoms.indices {
      let centerType = parameters.atoms.centerTypes[atomID]
      guard centerType == .quaternary else {
        continue
      }
      
      var closeToSurface = false
      for neighborID in neighbors[atomID] {
        let centerType = parameters.atoms.centerTypes[Int(neighborID)]
        if centerType != .quaternary {
          closeToSurface = true
        }
      }
      if closeToSurface {
        continue
      }
      
      parameters.atoms.masses[atomID] = 0
    }
    
    // Create the rigid body, but don't modify its position.
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
}

//
//  NCFPart.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/5/24.
//

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

struct NCFPart {
  var rigidBody: MM4RigidBody
  
  init(forces: MM4ForceOptions = [.bend, .stretch, .nonbonded]) {
    // 0.7 ms
    var topology = Topology()
    Self.compilationPass0(topology: &topology)
    Self.compilationPass1(topology: &topology)
    Self.compilationPass2(topology: &topology)
    
    var descriptor = MM4ParametersDescriptor()
    descriptor.atomicNumbers = topology.atoms.map(\.atomicNumber)
    descriptor.bonds = topology.bonds
    descriptor.forces = forces
    descriptor.hydrogenMassScale = 1
    let parameters = try! MM4Parameters(descriptor: descriptor)
    
    // How long does the rigid body take to initialize, with and without
    // torsion parameter generation?
    //
    // With torsion parameters: 22.0 ms
    // Without torsion parameters: 20.7 ms
    // With only nonbonded parameters: 20.9 ms
    //
    // With the optimizations that fixed bottlenecks during parameter
    // generation:
    //
    // With torsion parameters: 7.7 ms
    // Without torsion parameters: 3.8 ms
    // With only nonbonded parameters: 2.3 ms
    var rigidBody = MM4RigidBody(parameters: parameters)
    rigidBody.setPositions(topology.atoms.map(\.position))
    self.rigidBody = rigidBody
  }
  
  static func compilationPass0(topology: inout Topology) {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      
      let thickness: Float = 3
      let spacing: Float = 8
      let boundsH: Float = (3+1)*spacing
      Bounds { boundsH * h + 4 * h2k + 1 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        let cuts = 1 + Int((boundsH/spacing).rounded(.up))
        for i in 0..<cuts {
          Concave {
            Origin { 3.5 * h2k }
            Origin { Float(i) * spacing * h }
            Convex {
              Plane { h + k }
            }
            Convex {
              Plane { h2k }
            }
            Convex {
              Origin { thickness * h }
              Plane { k }
            }
          }
        }
        
        Origin { (-spacing/2) * h }
        for i in 0..<(cuts+1) {
          Concave {
            Origin { 0.5 * h2k }
            Origin { Float(i) * spacing * h }
            Convex {
              Plane { -k }
            }
            Convex {
              Plane { -h2k }
            }
            Convex {
              Origin { thickness * h }
              Plane { -k - h }
            }
          }
        }
        
        Replace { .empty }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  static func compilationPass1(topology: inout Topology) {
    let matches = topology.match(topology.atoms)
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      let match = matches[i]
      for j in match where i < j {
        insertedBonds.append(
          SIMD2(UInt32(i), UInt32(j)))
      }
    }
    topology.insert(bonds: insertedBonds)
    insertedBonds = []
    
    let orbitals = topology.nonbondingOrbitals()
    var insertedAtoms: [Entity] = []
    for i in topology.atoms.indices {
      let atom = topology.atoms[i]
      let bondLength = Element.hydrogen.covalentRadius +
      Element(rawValue: atom.atomicNumber)!.covalentRadius
      
      for orbital in orbitals[i] {
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        let position = atom.position + bondLength * orbital
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(
          SIMD2(UInt32(i), UInt32(hydrogenID)))
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  static func compilationPass2(topology: inout Topology) {
    topology.sort()
  }
}

extension NCFPart {
  func profileBulkPropertyComputation() {
    print("profiling bulk property computation:")
    do {
      let start = cross_platform_media_time()
      let mass = rigidBody.mass
      let end = cross_platform_media_time()
      print("-", String(format: "%.2f", (end - start) * 1e6), "µs",
            "mass", mass)
    }
    
    do {
      let start = cross_platform_media_time()
      let mass = rigidBody.mass
      let end = cross_platform_media_time()
      print("-", String(format: "%.2f", (end - start) * 1e6), "µs",
            "mass", mass)
    }
    
    do {
      let start = cross_platform_media_time()
      let centerOfMass = rigidBody.centerOfMass
      let end = cross_platform_media_time()
      print("-", String(format: "%.2f", (end - start) * 1e6), "µs",
            "center of mass", centerOfMass)
    }
    
    do {
      let start = cross_platform_media_time()
      let momentOfInertia = rigidBody.momentOfInertia
      let end = cross_platform_media_time()
      print("-", String(format: "%.2f", (end - start) * 1e6), "µs",
            "moment of inertia", momentOfInertia)
    }
    
    do {
      let start = cross_platform_media_time()
      let linearVelocity = rigidBody.linearVelocity
      let end = cross_platform_media_time()
      print("-", String(format: "%.2f", (end - start) * 1e6), "µs",
            "linear velocity", linearVelocity)
    }
    
    do {
      let start = cross_platform_media_time()
      let angularVelocity = rigidBody.angularVelocity
      let end = cross_platform_media_time()
      print("-", String(format: "%.2f", (end - start) * 1e6), "µs",
            "angular velocity", angularVelocity)
    }
  }
}

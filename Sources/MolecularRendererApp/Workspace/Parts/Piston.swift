//
//  Piston.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/2/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct Piston {
  var rigidBody: MM4RigidBody
  
  init() {
    let lattice = Self.createLattice()
    let topology = Self.createTopology(lattice: lattice)
    rigidBody = Self.createRigidBody(topology: topology)
    rigidBody.centerOfMass.y = .zero
  }
  
  static func createLattice() -> Lattice<Hexagonal> {
    Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 50 * h + 7 * h2k + 7 * l }
      Material { .elemental(.carbon) }
      
      func createBlock() {
        Convex {
          Origin { 4.99 * l }
          Plane { l }
        }
      }
      
      func createAxle() {
        Convex {
          Origin { 2 * h + 3.75 * h2k }
          
          var directions: [SIMD3<Float>] = []
          directions.append(k + 2 * h)
          directions.append(k - h)
          directions.append(-h2k)
          for direction in directions {
            Convex {
              Origin { 0.7 * direction }
              Plane { direction }
            }
          }
          
          let negativeDirections = directions.map(-)
          for direction in negativeDirections {
            Convex {
              Origin { 0.8 * direction }
              Plane { direction }
            }
          }
        }
      }
      
      Volume {
        Concave {
          createBlock()
          createAxle()
        }
        Replace { .empty }
      }
    }
  }
  
  static func createTopology(lattice: Lattice<Hexagonal>) -> Topology {
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

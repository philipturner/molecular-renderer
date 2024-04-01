//
//  Housing.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/1/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct Housing {
  var rigidBody: MM4RigidBody
  
  init() {
    let lattice = Self.createLattice()
    let topology = Self.createTopology(lattice: lattice)
    rigidBody = Self.createRigidBody(topology: topology)
  }
  
  static func createLattice() -> Lattice<Hexagonal> {
    Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 100 * h + 50 * h2k + 6 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 50 * h + 25 * h2k }
        
        var directions: [SIMD3<Float>] = []
        directions.append(h)
        directions.append((h + k + h) / Float(3).squareRoot())
        directions.append(k + h)
        directions.append((k + h + k) / Float(3).squareRoot())
        directions.append(k)
        directions.append((k - h) / Float(3).squareRoot())
        directions += directions.map(-)
        
        // Trim the inner side, where the flywheel will reside.
        Concave {
          Convex {
            Origin { 3.99 * l }
            Plane { l }
          }
          for direction in directions {
            Convex {
              Origin { 33 * direction }
              Plane { -direction }
            }
          }
        }
        Concave {
          for direction in directions {
            Convex {
              Origin { 25 * direction }
              Plane { -direction }
            }
          }
        }
        
        // Trim the outer side.
        for direction in directions {
          Convex {
            Origin { 40 * direction }
            Plane { direction }
          }
        }
        for direction in directions {
          Convex {
            Origin { 35 * direction }
            Plane { direction - l }
          }
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

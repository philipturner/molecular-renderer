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
  
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 130 * h + 30 * k + 18 * l }
      Material { .elemental(.carbon) }
      
      func createBoard() {
        Convex {
          Origin { 20 * h }
          Plane { -h }
          
          Origin { 10 * l }
          Plane { l }
        }
      }
      
      var flatDirections: [SIMD3<Float>] = []
      flatDirections.append(h)
      flatDirections.append(k)
      flatDirections += flatDirections.map(-)
      
      var diagonalDirections: [SIMD3<Float>] = []
      diagonalDirections.append(h + k)
      diagonalDirections.append(h - k)
      diagonalDirections += diagonalDirections.map(-)
      
      func createInnerAxle() {
        Convex {
          Origin { 15 * h + 15 * k }
          
          for direction in flatDirections {
            Convex {
              Origin { 11 * direction }
              Plane { direction }
            }
          }
          for direction in diagonalDirections {
            Convex {
              Origin { 8 * direction }
              Plane { direction }
            }
          }
        }
      }
      
      func createOuterAxle() {
        Convex {
          Origin { 15 * h + 15 * k }
          
          for direction in flatDirections {
            Convex {
              Origin { 15 * direction }
              Plane { direction }
            }
          }
          for direction in diagonalDirections {
            Convex {
              Origin { 11 * direction }
              Plane { direction }
            }
          }
          
          Origin { 13 * l }
          Plane { l }
        }
      }
      
      func createGuide() {
        Convex {
          Origin { 15 * k }
          
          Convex {
            Origin { 36 * h }
            Plane { -h }
          }
          
          Concave {
            Origin { 40 * h }
            Plane { -h }
            
            Convex {
              Origin { 8 * k }
              Plane { -h - k }
            }
            Convex {
              Origin { -8 * k }
              Plane { -h + k }
            }
          }
          
          Concave {
            Convex {
              Origin { 8 * k }
              Plane { -k }
            }
            Convex {
              Origin { -8 * k }
              Plane { k }
            }
            Convex {
              Origin { 13 * l }
              Plane { l }
            }
          }
        }
      }
      
      Volume {
        Concave {
          createBoard()
          createInnerAxle()
          createOuterAxle()
          createGuide()
        }
        Concave {
          Origin { 41 * h + (15 + 10) * k }
          Plane { h + k }
          Plane { k }
          
          Origin { 5 * l }
          Plane { k - l }
        }
        Concave {
          Origin { 41 * h + (15 - 10) * k }
          Plane { h - k }
          Plane { -k }
          
          Origin { 5 * l }
          Plane { -k - l }
        }
        Replace { .empty }
      }
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

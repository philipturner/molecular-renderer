//
//  DriveSystemHousing.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/1/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct DriveSystemHousing {
  var rigidBody: MM4RigidBody
  
  init() {
    let lattice = Self.createLattice()
    let topology = Self.createTopology(lattice: lattice)
    rigidBody = Self.createRigidBody(topology: topology)
  }
  
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 90 * h + 20 * k + 14 * l }
      Material { .elemental(.carbon) }
      
      func createBoard() {
        Convex {
          Origin { 13 * h }
          Plane { -h }
          
          Origin { 7 * l }
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
          Origin { 10 * h + 10 * k }
          
          for direction in flatDirections {
            Convex {
              Origin { 7 * direction }
              Plane { direction }
            }
          }
          for direction in diagonalDirections {
            Convex {
              Origin { 5 * direction }
              Plane { direction }
            }
          }
        }
      }
      
      func createOuterAxle() {
        Convex {
          Origin { 10 * h + 10 * k }
          
          for direction in flatDirections {
            Convex {
              Origin { 10 * direction }
              Plane { direction }
            }
          }
          for direction in diagonalDirections {
            Convex {
              Origin { 7.5 * direction }
              Plane { direction }
            }
          }
          
          Origin { 9 * l }
          Plane { l }
        }
      }
      
      func createGuide() {
        Convex {
          Origin { 10 * k }
          
          Convex {
            Origin { 24 * h }
            Plane { -h }
          }
          
          Concave {
            Origin { 26.5 * h }
            Plane { -h }
            
            Convex {
              Origin { 5.5 * k }
              Plane { -h - k }
            }
            Convex {
              Origin { -5.5 * k }
              Plane { -h + k }
            }
          }
          
          Concave {
            Convex {
              Origin { 5.25 * k }
              Plane { -k }
            }
            Convex {
              Origin { -5.25 * k }
              Plane { k }
            }
            Convex {
              Origin { 9 * l }
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
          Origin { 27 * h + (10 + 7) * k }
          Plane { h + k }
          Plane { k }
          
          Origin { 3.5 * l }
          Plane { k - l }
        }
        Concave {
          Origin { 27 * h + (10 - 7) * k }
          Plane { h - k }
          Plane { -k }
          
          Origin { 3.5 * l }
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

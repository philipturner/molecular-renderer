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
      Bounds { 36 * h + 6 * k + 4 * l }
      Material { .elemental(.carbon) }
      
      // Fix the warping.
      func createIndent(start: Float, end: Float, front: Bool) {
        Volume {
          Concave {
            Origin { Float(start) * h }
            Plane { h }
            
            if !front {
              Origin { 0.25 * l }
              Plane { -l }
            } else {
              Origin { 3.75 * l }
              Plane { l }
            }
            
            Origin { Float(end - start) * h }
            Plane { -h }
          }
          Replace { .empty }
        }
      }
      createIndent(start: 1, end: 3, front: false)
      createIndent(start: 7, end: 9, front: true)
      createIndent(start: 12, end: 14, front: false)
      createIndent(start: 17, end: 19, front: true)
      createIndent(start: 22, end: 25, front: false)
      createIndent(start: 27, end: 29, front: true)
      createIndent(start: 32, end: 35, front: false)
      
      // Engrave the text: "nano"
      func createPixel(position: SIMD2<Float>) {
        Volume {
          let offsetH = Float(position.x)
          let offsetK = Float(position.y)
          Origin { offsetH * h + offsetK * k }
          for segmentID in 0..<2 {
            Concave {
              Origin { -0.25 * h }
              Plane { h }
              Origin { 0.5 * h }
              Plane { -h }
              
              Origin { -0.25 * k }
              Plane { k }
              Origin { 0.5 * k }
              Plane { -k }
              
              if segmentID == 0 {
                Convex {
                  Origin { 0.5 * l }
                  Plane { l }
                }
                Convex {
                  Origin { 2.5 * l }
                  Plane { -l }
                }
              } else {
                Origin { 3.5 * l }
                Plane { l }
              }
            }
          }
          Replace { .atom(.germanium) }
        }
      }
      
      let pattern1: [String] = [
        "00|0||00000||||000000|0||00000|||||0",
        "00|||||0000000||00000|||||0000|000|0",
        "00||00|0000|||||00000||00|0000|000|0",
        "00|000|0000|00||00000|000|0000|000|0",
        "00|000|0000|||||00000|000|0000|||||0",
      ]
      
      for lineID in pattern1.indices {
        let line: String = pattern1[lineID]
        line.withCString { cString in
          let zeroRawValue = Character("0").asciiValue!
          for characterID in 0..<36 {
            let character = cString[characterID]
            guard character != zeroRawValue else {
              continue
            }
            
            let positionY = Float(5 - lineID)
            let positionX = Float(characterID)
            createPixel(position: SIMD2(positionX, positionY))
          }
        }
      }
      
      let pattern2: [String] = [
        "00|000000000|||000000|000000000||||0",
        "00|0|||00000000|00000|0|||0000||00||",
        "00|||0||0000000|00000|||0||000|0000|",
        "00||000|000|||||00000||000|000|0000|",
        "00|0000|000||0||00000|0000|000||00||",
        "00|0000|0000||0|00000|0000|0000||||0",
        "000000000000000000000000000000000000",
      ]
      
      for lineID in pattern2.indices {
        let line: String = pattern2[lineID]
        line.withCString { cString in
          let zeroRawValue = Character("0").asciiValue!
          for characterID in 0..<36 {
            let character = cString[characterID]
            guard character != zeroRawValue else {
              continue
            }
            
            let positionY = Float(6 - lineID) - 0.5
            let positionX = Float(characterID) - 0.5
            createPixel(position: SIMD2(positionX, positionY))
          }
        }
      }
      
      // Create holes for the knobs to fit inside.
      func createHole(offsetH: Float) {
        Volume {
          Origin { offsetH * h + 3 * k }
          
          // TODO: Fix the knobs and holes. They're currently misaligned with
          // the letters 'nano', clipping some letters and making then harder
          // to reading.
          Concave {
//            Convex {
//              Origin { 3 * l }
//              Plane { -l }
//            }
            
            var straightDirections: [SIMD3<Float>] = []
            straightDirections.append(h)
            straightDirections.append(k)
            straightDirections += straightDirections.map(-)
            for direction in straightDirections {
              Convex {
                Origin { 1.75 * direction }
                Plane { -direction }
              }
            }
            
            var diagonalDirections: [SIMD3<Float>] = []
            diagonalDirections.append(-h + k)
            diagonalDirections.append(h + k)
            diagonalDirections += diagonalDirections.map(-)
            for direction in diagonalDirections {
              Convex {
                Origin { 1.5 * direction }
                Plane { -direction }
              }
            }
          }
          Replace { .empty }
        }
      }
      createHole(offsetH: 3.5)
      createHole(offsetH: 32.5)
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

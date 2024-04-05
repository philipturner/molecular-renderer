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
      Bounds { 38 * h + 6 * k + 4 * l }
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
      createIndent(start: 7, end: 10, front: true)
      createIndent(start: 13, end: 15, front: false)
      createIndent(start: 18, end: 20, front: true)
      createIndent(start: 23, end: 26, front: false)
      createIndent(start: 28, end: 31, front: true)
      createIndent(start: 34, end: 37, front: false)
      
      // Engrave the text: "nano"
      func createPixel(position: SIMD2<Float>, withBack: Bool = true) {
        Volume {
          let offsetH = Float(position.x)
          let offsetK = Float(position.y)
          Origin { offsetH * h + offsetK * k }
          
          var segmentStart: Int = 1
          var segmentEnd: Int = 2
          if withBack {
            segmentStart = 0
          }
          
          for segmentID in segmentStart..<segmentEnd {
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
                  Origin { 1.5 * l }
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
        "00|0||000000||||000000|0||000000|||||0",
        "00|||||00000000||00000|||||00000|000|0",
        "00||00|00000|||||00000||00|00000|000|0",
        "00|000|00000|00||00000|000|00000|000|0",
        "00|000|00000|||||00000|000|00000|||||0",
      ]
      
      for lineID in pattern1.indices {
        let line: String = pattern1[lineID]
        line.withCString { cString in
          let zeroRawValue = Character("0").asciiValue!
          for characterID in 0..<38 {
            let character = cString[characterID]
            guard character != zeroRawValue else {
              continue
            }
            
            let positionX = Float(characterID)
            let positionY = Float(5 - lineID)
            createPixel(position: SIMD2(positionX, positionY))
          }
        }
      }
      
      let pattern2: [String] = [
        "00|0000000000|||000000|0000000000||||0",
        "00|0|||000000000|00000|0|||00000||000|",
        "00|||0||00000000|00000|||0||0000|0000|",
        "00||000|0000|||||00000||000|0000|0000|",
        "00|0000|0000||0||00000|0000|0000|000||",
        "00|0000|00000||0|00000|0000|00000||||0",
        "00000000000000000000000000000000000000",
      ]
      
      for lineID in pattern2.indices {
        let line: String = pattern2[lineID]
        line.withCString { cString in
          let zeroRawValue = Character("0").asciiValue!
          for characterID in 0..<38 {
            let character = cString[characterID]
            guard character != zeroRawValue else {
              continue
            }
            
            let positionX = Float(characterID) - 0.5
            let positionY = Float(6 - lineID) - 0.5
            createPixel(position: SIMD2(positionX, positionY))
          }
        }
      }
      
      // Make the 'n' more clear, since it's partially obstructed by the knob.
      createPixel(position: SIMD2(3.25, 4.75), withBack: false)
      
      // Create holes for the knobs to fit inside.
      func createHole(offsetH: Float) {
        Volume {
          Origin { offsetH * h + 3 * k }
          
          Concave {
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
      createHole(offsetH: 4.00)
      createHole(offsetH: 34.00)
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

extension ConnectingRod {
  // This must be minimized before adding to the system, otherwise hydrogens
  // will fly off.
  mutating func minimize() {
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = rigidBody.parameters
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    forceField.positions = rigidBody.positions
    forceField.minimize(tolerance: 10)

    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = rigidBody.parameters
    rigidBodyDesc.positions = Array(forceField.positions)
    rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
}

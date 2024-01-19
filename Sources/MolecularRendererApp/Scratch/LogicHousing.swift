//
//  LogicHousing.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/19/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct LogicHousingDescriptor {
  /// The grooves to etch out of the sides.
  var grooves: LogicHousing.GrooveOptions = []
  
  init() {
    
  }
}

struct LogicHousing {
  var topology = Topology()
  
  struct GrooveOptions: OptionSet {
    var rawValue: UInt32
    
    static let lowerLeft = GrooveOptions(rawValue: 1 << 0)
    static let lowerFront = GrooveOptions(rawValue: 1 << 1)
    static let lowerRight = GrooveOptions(rawValue: 1 << 2)
    static let lowerBack = GrooveOptions(rawValue: 1 << 3)
    static let lowerRodLeftRight = GrooveOptions(rawValue: 1 << 4)
    static let lowerRodFrontBack = GrooveOptions(rawValue: 1 << 5)
    
    static let upperLeft = GrooveOptions(rawValue: 1 << 10)
    static let upperFront = GrooveOptions(rawValue: 1 << 11)
    static let upperRight = GrooveOptions(rawValue: 1 << 12)
    static let upperBack = GrooveOptions(rawValue: 1 << 13)
    static let upperRodLeftRight = GrooveOptions(rawValue: 1 << 14)
    static let upperRodFrontBack = GrooveOptions(rawValue: 1 << 15)
    
    static let bottom = GrooveOptions(rawValue: 1 << 20)
    static let top = GrooveOptions(rawValue: 1 << 21)
  }
  
  init(descriptor: LogicHousingDescriptor) {
    createLattice(descriptor: descriptor)
    passivateSurfaces()
  }
  
  mutating func createLattice(descriptor: LogicHousingDescriptor) {
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 8 * h + 10 * k + 8 * l }
      Material { .elemental(.carbon) }
      
      // Cut a hole for the rod to sit inside. Enter the direction perpendicular
      // to how the hole faces.
      func createRodVolume(perpendicularDirection: SIMD3<Float>) {
        Concave {
          Origin { 2 * (perpendicularDirection + k) }
          
          var loopDirections: [SIMD3<Float>] = []
          loopDirections.append(perpendicularDirection)
          loopDirections.append(k)
          loopDirections.append(-perpendicularDirection)
          loopDirections.append(-k)
          
          for i in 0..<4 {
            Convex {
              Origin { loopDirections[i] * 2 }
              if i == 1 {
                Origin { 0.25 * k }
              }
              Plane { -loopDirections[i] }
            }
            Convex {
              let current = loopDirections[i]
              let next = loopDirections[(i + 1) % 4]
              Origin { (current + next) * 2 }
              Origin { (current + next) * -0.25 }
              if i == 0 || i == 1 {
                Origin { 0.25 * k }
              }
              Plane { -(current + next) }
            }
          }
        }
      }
      
      Volume {
        if descriptor.grooves.contains(.lowerRodLeftRight) {
          Convex {
            Origin { 2 * l + 1.5 * k }
            createRodVolume(perpendicularDirection: l)
          }
        }
        if descriptor.grooves.contains(.lowerRodFrontBack) {
          Convex {
            Origin { 2 * h + 1.5 * k }
            createRodVolume(perpendicularDirection: h)
          }
        }
        if descriptor.grooves.contains(.upperRodLeftRight) {
          Convex {
            Origin { 2 * l + 4.25 * k }
            createRodVolume(perpendicularDirection:l)
          }
        }
        if descriptor.grooves.contains(.upperRodFrontBack) {
          Convex {
            Origin { 2 * h + 4.25 * k }
            createRodVolume(perpendicularDirection: h)
          }
        }
        
        func createGroove(direction: SIMD3<Float>, side: Bool, upper: Bool) {
          Concave {
            let signedDirection = (side ? 1 : -1) * direction
            Origin { (side ? 7 : 1) * direction }
            Plane { signedDirection }
            
            let verticalDirection = (upper ? 1 : -1) * k
            Origin { (upper ? 4.5 : 5.5) * k }
            Origin { 0.25 * (signedDirection + verticalDirection) }
            Plane { signedDirection + verticalDirection }
          }
        }
        
        // Test this by reproducing the same geometry as before - each of the
        // two parities.
        if descriptor.grooves.contains(.lowerLeft) {
          createGroove(direction: h, side: false, upper: false)
        }
        if descriptor.grooves.contains(.lowerFront) {
          createGroove(direction: l, side: true, upper: false)
        }
        if descriptor.grooves.contains(.lowerRight) {
          createGroove(direction: h, side: true, upper: false)
        }
        if descriptor.grooves.contains(.lowerBack) {
          createGroove(direction: l, side: false, upper: false)
        }
        
        if descriptor.grooves.contains(.upperLeft) {
          createGroove(direction: h, side: false, upper: true)
        }
        if descriptor.grooves.contains(.upperFront) {
          createGroove(direction: l, side: true, upper: true)
        }
        if descriptor.grooves.contains(.upperRight) {
          createGroove(direction: h, side: true, upper: true)
        }
        if descriptor.grooves.contains(.upperBack) {
          createGroove(direction: l, side: false, upper: true)
        }
        
        if descriptor.grooves.contains(.bottom) {
          Convex {
            Origin { 0.5 * k }
            Plane { -k }
          }
        }
        if descriptor.grooves.contains(.top) {
          Convex {
            Origin { 9.5 * k }
            Plane { k }
          }
        }
        
        
        // Old code for debugging/reference.
//        Convex {
//          Concave {
//            Origin { 1 * h }
//            Plane { -h }
//            Origin { 5.5 * k }
//            Origin { 0.25 * (-h - k) }
//            Plane { -h - k }
//          }
//          Concave {
//            Origin { 7 * h }
//            Plane { h }
//            Origin { 5.5 * k }
//            Origin { 0.25 * (h - k) }
//            Plane { h - k }
//          }
//          
//          Concave {
//            Origin { 1 * l }
//            Plane { -l }
//            Origin { 4.5 * k }
//            Origin { 0.25 * (-l + k) }
//            Plane { -l + k }
//          }
//          Concave {
//            Origin { 7 * l }
//            Plane { l }
//            Origin { 4.5 * k }
//            Origin { 0.25 * (l + k) }
//            Plane { l + k }
//          }
//        }
//        
//        Convex {
//          if parity {
//            Origin { 0.5 * k }
//            Plane { -k }
//          } else {
//            Origin { 9.5 * k }
//            Plane { k }
//          }
//        }
        
        Origin { 4 * h + 4 * l }
        let directions = [h, l, -h, -l]
        for direction in directions {
          Convex {
            Origin { 3.5 * direction }
            Plane { direction }
          }
        }
        
        Replace { .empty }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  mutating func passivateSurfaces() {
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
}

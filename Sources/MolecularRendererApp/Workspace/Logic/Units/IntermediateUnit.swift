//
//  IntermediateUnit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/12/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct IntermediateUnit {
  var propagate: [Rod]
  var generate: [Rod]
  var driveWall: DriveWall
  
  var holePatterns: [HolePattern] = []
  var rods: [Rod] {
    var output: [Rod] = []
    output.append(contentsOf: propagate)
    output.append(contentsOf: generate)
    return output
  }
  
  init() {
    let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
    let latticeX = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 32 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      // Drive wall interface.
      Volume {
        Concave {
          Concave {
            Origin { 1 * h2k }
            Plane { h2k }
            Origin { 1 * h }
            Plane { h2k - 3 * h } // k - h
          }
          Convex {
            Origin { 1.5 * h2k }
            Plane { h2k }
            Origin { 0.5 * h }
            Plane { -h }
          }
        }
        Replace { .empty }
      }
    }
    
    var rodX = Rod(lattice: latticeX)
    rodX.rigidBody.rotate(angle: -.pi, axis: [0, 1, 0])
    do {
      var center = rodX.rigidBody.centerOfMass
      center = SIMD3(-center.x, center.y, center.z)
      center.x += 22.75 * latticeConstant
      rodX.rigidBody.centerOfMass = center
    }
    
    var holeOffsets: [SIMD3<Float>] = []
    
    do {
      var offset = SIMD3<Float>(0, 0.75 + 2.5, 0.75)
      var source = rodX
      source.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      source.rigidBody.centerOfMass += SIMD3(0, 0.85, 0.91)
      propagate = Self.createLayers(source: source)
      
      offset += SIMD3(0, 1.5, 1.5)
      holeOffsets.append(offset)
    }
    
    do {
      var offset = SIMD3<Float>(0, 0.75 + 2.5, 0.75 + 6.25)
      var source = rodX
      source.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      source.rigidBody.centerOfMass += SIMD3(0, 0.85, 0.91)
      generate = Self.createLayers(source: source)
      
      offset += SIMD3(0, 1.5, 1.5)
      holeOffsets.append(offset)
    }
    
    for offset in holeOffsets {
      // Emulate the presence of other layers in the logic unit.
      for layerID in -1...2 {
        let y = 6.25 * Float(layerID)
        holePatterns.append(
          Self.createHolePatternX(offset: SIMD3(0, y, 0) + offset))
      }
    }
    
    var rampPatterns = HalfAdder.createBoundingPatterns()
    for offset in holeOffsets {
      // Emulate the presence of other layers in the logic unit.
      for layerID in -1...2 {
        let y = -3.25 + 6.25 * Float(layerID)
        rampPatterns.append(
          Self.createRampPatternX(offset: SIMD3(22.75, y, 0) + offset))
      }
    }
    driveWall = Self.createDriveWall(patterns: rampPatterns)
  }
}

extension IntermediateUnit {
  // Spawns the logic rods for all Y layers, from a single source rod.
  static func createLayers(source: Rod) -> [Rod] {
    let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
    let spacing = 6.25 * latticeConstant
    
    var output: [Rod] = []
    for layerID in 0..<2 {
      var rod = source
      rod.rigidBody.centerOfMass.y += spacing * Double(layerID)
      output.append(rod)
    }
    return output
  }
  
  static func createHolePatternX(offset: SIMD3<Float>) -> HolePattern {
    { h, k, l in
      Origin { offset[0] * h + offset[1] * k + offset[2] * l }
      
      Concave {
        Concave {
          Plane { k }
          Plane { l }
        }
        Concave {
          Origin { 4.25 * k + 4 * l }
          Plane { -k }
          Plane { -l }
        }
      }
      
      Replace { .empty }
    }
  }
  
  static func createRampPatternX(offset: SIMD3<Float>) -> RampPattern {
    { h, k, l in
      Origin { offset[0] * h + offset[1] * k + offset[2] * l }
      
      Concave {
        Concave {
          Plane { k }
          Plane { l }
        }
        Concave {
          Origin { 4 * l }
          Plane { -l }
        }
        Concave {
          Plane { -h - k }
          Origin { 2 * -h }
          Plane { -h }
        }
      }
      
      Replace { .empty }
    }
  }
}

extension IntermediateUnit {
  static func createDriveWall(patterns: [RampPattern]) -> DriveWall {
    var driveWallDesc = DriveWallDescriptor()
    driveWallDesc.dimensions = SIMD3(23, 18, 15)
    driveWallDesc.patterns = patterns
    driveWallDesc.patterns.append { h, k, l in
      Origin { 16.75 * h }
      Plane { -h }
      Replace { .empty }
    }
    driveWallDesc.patterns.append { h, k, l in
      Origin { 17.25 * h }
      Plane { -h }
      Replace { .empty }
    }
    driveWallDesc.patterns.append { h, k, l in
      Origin { 21.75 * h }
      Plane { h }
      Replace { .empty }
    }
    
    let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
    var driveWall = DriveWall(descriptor: driveWallDesc)
    driveWall.rigidBody.centerOfMass.x += (5.5 + 1) * latticeConstant
    return driveWall
  }
}

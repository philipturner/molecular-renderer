//
//  APMBootstrapper.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/11/23.
//

import Foundation
import MolecularRenderer
import QuaternionModule
import simd

struct APMBootstrapper: MRAtomProvider {
  var surface = GoldSurface()
  var habTools: [HabTool]
  var reportedAtoms = false
  
  init() {
    let numTools = 100
    srand48(79) // seed with atomic number of Au
    var offsets: [SIMD2<Float>] = []
    
    for i in 0..<numTools {
      var offset = SIMD2(Float(drand48()), Float(drand48()))
      offset.x = cross_platform_mix(-7, 7, offset.x)
      offset.y = cross_platform_mix(-7, 7, offset.y)
      
      var numTries = 0
      while offsets.contains(where: { cross_platform_distance($0, offset) < 1.0 }) {
        numTries += 1
        if numTries > 100 {
          print(offsets)
          print(offset)
          fatalError("Random generation failed to converge @ \(i).")
        }
        
        offset = SIMD2(Float(drand48()), Float(drand48()))
        offset.x = cross_platform_mix(-7, 7, offset.x)
        offset.y = cross_platform_mix(-7, 7, offset.y)
      }
      offsets.append(offset)
    }
    
    // Measured in revolutions, not radians.
    let rotations: [Float] = (0..<numTools).map { _ in
      return Float(drand48())
    }
    
    habTools = zip(offsets, rotations).map { (offset, rotation) in
      let x: Float = offset.x
      let z: Float = offset.y
      let radians = rotation * 2 * .pi
      let orientation = Quaternion<Float>(angle: radians, axis: [0, 1, 0])
      return HabTool(x: x, z: z, orientation: orientation)
    }
  }
  
  mutating func atoms(time: MRTimeContext) -> [MRAtom] {
    var atoms = surface.atoms
    for habTool in habTools {
      atoms.append(contentsOf: habTool.atoms)
    }
    if !reportedAtoms {
      reportedAtoms = true
      print("Rendering \(atoms.count) atoms.")
    }
    return atoms
  }
}

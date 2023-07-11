//
//  APMBootstrapper.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/11/23.
//

import Foundation
import MolecularRenderer
import simd

struct GoldSurface {
  var atoms: [MRAtom]
  
  init() {
    var plane: [MRAtom] = []
    let spacing: Float = 0.40782
    let size = Int(8 / spacing)
    for x in -size..<size {
      for z in -size..<size {
        let coords = SIMD3<Int>(x, 0, z)
        plane.append(MRAtom(
          origin: spacing * SIMD3(coords), element: 79))
      }
    }
    atoms = plane
    
    let offsets: [SIMD3<Float>] = [
      SIMD3(spacing / 2, -spacing / 2, 0),
      SIMD3(0, -spacing / 2, spacing / 2),
      SIMD3(spacing / 2, 0, spacing / 2),
    ]
    for offset in offsets {
      atoms += plane.map { input in
        var atom = input
        atom.origin += offset
        return atom
      }
    }
    
    var newAtoms = atoms
    for y in -2..<0 {
      newAtoms += atoms.map { input in
        var atom = input
        atom.origin.y += Float(y) * spacing
        return atom
      }
    }
    self.atoms = newAtoms
  }
}

struct HabTool {
  static let baseAtoms = ExampleProviders.adamantaneHabTool()._atoms
  
  var atoms: [MRAtom]
  
  init(x: Float, z: Float, orientation: simd_quatf) {
    self.atoms = Self.baseAtoms.map { input in
      var atom = input
      atom.origin = orientation.act(atom.origin)
      atom.origin.y += 0.6
      atom.origin.x += x
      atom.origin.z += z
      return atom
    }
  }
}

struct APMBootstrapper: MRAtomProvider {
  var surface = GoldSurface()
  var habTools: [HabTool]
  
  init() {
    let numTools = 100
    srand48(79) // seed with atomic number of Au
    var offsets: [SIMD2<Float>] = []
    
    for i in 0..<numTools {
      var offset = SIMD2(Float(drand48()), Float(drand48()))
      offset.x = simd_mix(-7, 7, offset.x)
      offset.y = simd_mix(-7, 7, offset.y)
      
      var numTries = 0
      while offsets.contains(where: { distance($0, offset) < 1 }) {
        numTries += 1
        if numTries > 100 {
          print(offsets)
          print(offset)
          fatalError("Random generation failed to converge @ \(i).")
        }
        
        offset = SIMD2(Float(drand48()), Float(drand48()))
        offset.x = simd_mix(-7, 7, offset.x)
        offset.y = simd_mix(-7, 7, offset.y)
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
      let orientation = simd_quatf(angle: radians, axis: [0, 1, 0])
      return HabTool(x: x, z: z, orientation: orientation)
    }
  }
  
  func atoms(time: MRTimeContext) -> [MRAtom] {
    var atoms = surface.atoms
    for habTool in habTools {
      atoms.append(contentsOf: habTool.atoms)
    }
    print(atoms.count)
    return atoms
  }
}

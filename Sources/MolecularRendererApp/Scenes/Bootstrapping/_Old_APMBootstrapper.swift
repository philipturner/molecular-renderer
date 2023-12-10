//
//  _Old_APMBootstrapper.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/10/23.
//

import Foundation
import MolecularRenderer
import QuaternionModule
import simd

struct _Old_APMBootstrapper: MRAtomProvider {
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
  
  struct HabTool {
    static let baseAtoms = { () -> [MRAtom] in
      let url = URL(string: "https://gist.githubusercontent.com/philipturner/6405518fadaf902492b1498b5d50e170/raw/d660f82a0d6bc5c84c0ec1cdd3ff9140cd7fa9f2/adamantane-thiol-Hab-tool.pdb")!
      let parser = PDBParser(url: url, hasA1: true)
      var atoms = parser._atoms
      
      var sulfurs = atoms.filter { $0.element == 16 }
      precondition(sulfurs.count == 3)
      
      let normal = cross_platform_cross(sulfurs[2].origin - sulfurs[0].origin,
                                        sulfurs[1].origin - sulfurs[0].origin)
      
      let rotation = Quaternion<Float>(from: cross_platform_normalize(normal), to: [0, 1, 0])
      for i in 0..<atoms.count {
        var atom = atoms[i]
        atom.origin = rotation.act(on: atom.origin)
        atom.origin += [0, 1, 0]
        atoms[i] = atom
      }
      
      sulfurs = atoms.filter { $0.element == 16 }
      let height = sulfurs[0].origin.y
      for i in 0..<atoms.count {
        atoms[i].origin.y -= height
      }
      
      return atoms
    }()
    
    var atoms: [MRAtom]
    
    init(x: Float, z: Float, orientation: Quaternion<Float>) {
      self.atoms = Self.baseAtoms.map { input in
        var atom = input
        atom.origin = orientation.act(on: atom.origin)
        atom.origin.y += 0.4
        atom.origin.x += x
        atom.origin.z += z
        return atom
      }
    }
  }

  struct GoldSurface {
    var atoms: [MRAtom]
    
    init() {
      let spacing: Float = 0.40782
      let size = Int(16 / spacing)
      let cuboid = GoldCuboid(
        latticeConstant: spacing, plane: .fcc100(size, 3, size))
      self.atoms = cuboid.atoms
      
      for i in 0..<atoms.count {
        atoms[i].origin.y -= 1 * spacing
      }
    }
  }
}

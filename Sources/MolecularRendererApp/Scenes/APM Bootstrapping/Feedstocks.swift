//
//  Feedstocks.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/11/23.
//

import Foundation
import MolecularRenderer
import QuaternionModule
import simd

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

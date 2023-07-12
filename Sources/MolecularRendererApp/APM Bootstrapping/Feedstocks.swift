//
//  Feedstocks.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/11/23.
//

import Foundation
import MolecularRenderer
import simd

struct HabTool {
  static let baseAtoms = { () -> [MRAtom] in
    let url = URL(string: "https://gist.githubusercontent.com/philipturner/334ec8cd769194c6f306f500f12d79ff/raw/0cbcbf749210551dbf7037cd6bab79dbffc468b4/HighLongLinkersCarbaGermatraneSilylated.pdb")!
    let parser = PDBParser(url: url, hasA1: false)
    var atoms = parser._atoms
    
    var sulfurs = atoms.filter { $0.element == 16 }
    precondition(sulfurs.count == 3)
    
    let normal = cross(sulfurs[1].origin - sulfurs[0].origin,
                       sulfurs[2].origin - sulfurs[0].origin)
    
    let rotation = simd_quatf(from: normalize(normal), to: [0, 1, 0])
    for i in 0..<atoms.count {
      var atom = atoms[i]
      atom.origin = rotation.act(atom.origin)
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
  
  init(x: Float, z: Float, orientation: simd_quatf) {
    self.atoms = Self.baseAtoms.map { input in
      var atom = input
      atom.origin = orientation.act(atom.origin)
      atom.origin.y += 0.4
      atom.origin.x += x
      atom.origin.z += z
      return atom
    }
  }
}

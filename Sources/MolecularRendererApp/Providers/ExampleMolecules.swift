//
//  ExampleMolecules.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/15/23.
//

import Foundation
import MolecularRenderer

struct ExampleMolecules {
  // Structure sourced from:
  // https://commons.wikimedia.org/wiki/File:Ethylene-CRC-MW-dimensions-2D-Vector.svg
  struct Ethylene: MRAtomProvider {
    var _atoms: [MRAtom]
    
    init(styleProvider: MRAtomStyleProvider) {
      let z_offset: Float = -1 // -2
      let c_offset_x: Float = 0.1339 / 2 // 0.20
      let carbon_origins: [SIMD3<Float>] = [
        SIMD3(-c_offset_x, 0, z_offset),
        SIMD3(+c_offset_x, 0, z_offset),
      ]
      
      let angle: Float = (180 - 121.3) * .pi / 180
      let h_offset_x: Float = 0.1087 * cos(angle) + c_offset_x // 0.50
      let h_offset_y: Float = 0.1087 * sin(angle) // 0.25
      let hydrogen_origins: [SIMD3<Float>] = [
        SIMD3(-h_offset_x, -h_offset_y, z_offset),
        SIMD3(-h_offset_x, +h_offset_y, z_offset),
        SIMD3(+h_offset_x, -h_offset_y, z_offset),
        SIMD3(+h_offset_x, +h_offset_y, z_offset),
      ]
      
      let styles = styleProvider.styles
      self._atoms = hydrogen_origins.map {
        MRAtom(styles: styles, origin: $0, element: 1)
      }
      self._atoms += carbon_origins.map {
        MRAtom(styles: styles, origin: $0, element: 6)
      }
    }
    
    func atoms(time: MRTimeContext) -> [MRAtom] {
      return _atoms
    }
  }
  
  struct TaggedEthylene: MRAtomProvider {
    var _atoms: [MRAtom]
    
    init(styleProvider: MRAtomStyleProvider) {
      let ethylene = Ethylene(styleProvider: styleProvider)
      self._atoms = ethylene._atoms
      
      let firstHydrogen = _atoms.firstIndex(where: { $0.element == 1 })!
      let firstCarbon = _atoms.firstIndex(where: { $0.element == 6 })!
      _atoms[firstHydrogen].flags = 0x1 | 0x2
      _atoms[firstCarbon].flags = 0x1 | 0x2
    }
    
    func atoms(time: MRTimeContext) -> [MRAtom] {
      return _atoms
    }
  }
}

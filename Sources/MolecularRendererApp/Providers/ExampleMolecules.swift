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
    
    init() {
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
      
      self._atoms = hydrogen_origins.map {
        MRAtom(origin: $0, element: 1)
      }
      self._atoms += carbon_origins.map {
        MRAtom(origin: $0, element: 6)
      }
    }
    
    func atoms(time: MRTimeContext) -> [MRAtom] {
      return _atoms
    }
  }
  
  struct TaggedEthylene: MRAtomProvider {
    var _atoms: [MRAtom]
    
    init() {
      let ethylene = Ethylene()
      self._atoms = ethylene._atoms
      
      let firstHydrogen = _atoms.firstIndex(where: { $0.element == 1 })!
      let firstCarbon = _atoms.firstIndex(where: { $0.element == 6 })!
      _atoms[firstHydrogen].element = 0
      _atoms[firstCarbon].element = 220
    }
    
    func atoms(time: MRTimeContext) -> [MRAtom] {
      return _atoms
    }
  }
  
  struct GoldSurface: MRAtomProvider {
    var _atoms: [MRAtom]
    
    init() {
      var origins: [SIMD3<Float>] = []
      
      let size = 2
      let separation: Float = 0.50
      for x in -size...size {
        for y in -size...size {
          for z in -size...size {
            let coords = SIMD3<Int>(x, y, z)
            origins.append(separation * SIMD3<Float>(coords))
          }
        }
      }
      
      _atoms = origins.map {
        MRAtom(origin: $0, element: 79)
      }
      
      // Sulfur atoms are interspersed. Although this is not a realistic
      // substance, it ensures the renderer provides enough contrast between the
      // colors for S and Au.
      _atoms += origins.map {
        let origin = $0 + SIMD3(repeating: separation / 2)
        return MRAtom(origin: origin, element: 16)
      }
      
      let pdbAtoms = ExampleProviders.adamantaneHabTool()._atoms
      _atoms += pdbAtoms.map {
        let origin = $0.origin + [0, 2, 0]
        return MRAtom(origin: origin, element: $0.element)
      }
    }
    
    func atoms(time: MRTimeContext) -> [MRAtom] {
      return _atoms
    }
  }
}

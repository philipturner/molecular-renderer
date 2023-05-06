//
//  ExampleMolecules.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/15/23.
//

import Foundation

struct ExampleMolecules {
  // Structure sourced from:
  // https://commons.wikimedia.org/wiki/File:Ethylene-CRC-MW-dimensions-2D-Vector.svg
  static let ethylene: [Atom] = {
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
    
    return hydrogen_origins.map {
      Atom(origin: $0, element: 1)
    } + carbon_origins.map {
      Atom(origin: $0, element: 6)
    }
  }()
  
  static let taggedEthylene: [Atom] = {
    var atoms = ExampleMolecules.ethylene
    let firstHydrogen = atoms.firstIndex(where: { $0.element == 1 })!
    let firstCarbon = atoms.firstIndex(where: { $0.element == 6 })!
    atoms[firstHydrogen].flags = 0x1 | 0x2
    atoms[firstCarbon].flags = 0x1 | 0x2
    return atoms
  }()
}

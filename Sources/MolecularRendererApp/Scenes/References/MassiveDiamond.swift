//
//  MassiveDiamond.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/12/23.
//

import Foundation
import MolecularRenderer

// Adversarial test case to find where dense grids break down, and sparse grids
// are needed.
struct MassiveDiamond: MRAtomProvider {
  var _atoms: [MRAtom]
  
  init() {
    let outerSize: Int = 10
    let thickness: Int? = 1
    let axesOpenLower: SIMD3<Int> = [0, 0, 0]
    let axesOpenUpper: SIMD3<Int> = [0, 1, 0]
    let plane = CrystalPlane.fcc100(outerSize, outerSize, outerSize)
    
    var hollowStart: SIMD3<Int>?
    var hollowEnd: SIMD3<Int>?
    if let thickness {
      let start = SIMD3<Int>(repeating: 0)
      let end = SIMD3<Int>(repeating: Int(outerSize))
      hollowStart = start &+ thickness
      hollowEnd = end &- thickness
      
      for i in 0..<3 {
        if axesOpenLower[i] > 0 {
          hollowStart![i] = Int(0) - 1
        }
        if axesOpenUpper[i] > 0 {
          hollowEnd![i] = Int(outerSize) + 1
        }
      }
    }
    let cuboid = DiamondCuboid(
      latticeConstant: 0.357,
      hydrogenBondLength: 0.109,
      plane: plane,
      hollowStart: hollowStart,
      hollowEnd: hollowEnd)
    _atoms = cuboid.atoms
    
    print("Number of atoms: \(_atoms.count)")
    
  }
  
  func atoms(time: MRTimeContext) -> [MRAtom] {
    return self._atoms
  }
}

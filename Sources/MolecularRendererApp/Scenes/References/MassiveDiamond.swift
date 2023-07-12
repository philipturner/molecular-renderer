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
// - Benchmarked quality: 7 samples/pixel
// - Benchmarked position: [0, 1.5, 0], looking at -Y
// - outerSize = 10 -> 16-bit references
// - outerSize = 100 -> 32-bit references (16-bit for sparse)
//
// Geometry stage:
//
// outerSize = 10
// - efficient render: ??? ms
// - high quality render: ??? ms
// outerSize = 100
// - efficient render: ??? ms
// - high quality render: ??? ms
//
// Rendering stage:
//
// outerSize = 10 -> adversarial case
// - efficient: ??? ms
// - high quality: ??? ms
//
// outerSize = 100 -> good case
// - efficient: ??? ms
// - high quality: ??? ms
struct MassiveDiamond: MRAtomProvider {
  var _atoms: [MRAtom]
  
  init(outerSize: Int) {
    let outerSize: Int = 10
    let extraDepth: Int = 100
    let dimensions: SIMD3<Int> = [outerSize, outerSize + extraDepth, outerSize]
    
    let thickness: Int? = 1
    let axesOpenLower: SIMD3<Int> = [0, 0, 0]
    let axesOpenUpper: SIMD3<Int> = [0, 1, 0]
    let plane = CrystalPlane.fcc100(outerSize, extraDepth, outerSize)
    
    var hollowStart: SIMD3<Int>?
    var hollowEnd: SIMD3<Int>?
    if let thickness {
      hollowStart = SIMD3<Int>(repeating: .zero) &+ thickness
      hollowEnd = dimensions &- thickness
      
      for i in 0..<3 {
        if axesOpenLower[i] > 0 {
          hollowStart![i] = -1
        }
        if axesOpenUpper[i] > 0 {
          hollowEnd![i] = dimensions[i] + 1
        }
      }
    }
    
    let latticeConstant: Float = 0.357
    let cuboid = DiamondCuboid(
      latticeConstant: 0.357,
      hydrogenBondLength: 0.109,
      plane: plane,
      hollowStart: hollowStart,
      hollowEnd: hollowEnd)
    _atoms = cuboid.atoms
    
    for i in 0..<_atoms.count {
      _atoms[i].origin.y -= Float(extraDepth) / 2 * latticeConstant
    }
    
    print("Number of atoms: \(_atoms.count)")
    
  }
  
  func atoms(time: MRTimeContext) -> [MRAtom] {
    return self._atoms
  }
}

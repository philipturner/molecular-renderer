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
// - Benchmarked position: [0, 1.5, 0], looking at -Y with camera space up = +X
// - outerSize = 10, thickness 1: 44705 atoms
// - outerSize = 100, thickness 2: 947968 atoms
//
// Geometry stage:
//
// outerSize = 10
// - 16-bit sparse: TODO
// - 32-bit sparse: TODO
// - 16-bit dense: 612 µs
// - 32-bit dense: 562 µs
// outerSize = 100
// - 16-bit sparse: TODO
// - 32-bit sparse: TODO
// - 32-bit dense: 3128 µs
//
// Render stage:
//
// outerSize = 10
// - 16-bit sparse: TODO
// - 32-bit sparse: TODO
// - 16-bit dense: 9.05 ms (failing right now)
// - 32-bit dense: 8.31 ms
//
// outerSize = 100
// - 16-bit sparse: TODO
// - 32-bit sparse: TODO
// - 32-bit dense: 4.11 ms
struct MassiveDiamond: MRAtomProvider {
  var _atoms: [MRAtom]
  
  init(outerSize: Int, thickness: Int? = nil) {
    let extraDepth: Int = 100
    let dimensions: SIMD3<Int> = [outerSize, outerSize + extraDepth, outerSize]
    
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

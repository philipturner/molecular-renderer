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
// - outerSize = 10, thickness 1
//   - 44705 atoms
//   - 16-bit references are fastest for rendering
// - outerSize = 100, thickness 2
//   - 947968 atoms
//   - 32-bit references are the only available type (for now)
//
// Geometry stage:
//
// outerSize = 10 -> good case
// - 16-bit references: 619 µs
// - 32-bit references: 586 µs
// outerSize = 100 -> stressing the limits
// - w/ efficient render: 3489 µs, 3114 µs min
// - w/ high quality render: 3784 µs typical, 3282 µs min
//
// Render stage:
//
// outerSize = 10 -> adversarial case
// - efficient: 27.64 ms
// - high quality: 27.57 ms
// TODO: In this case, how much % execution time is spent on the DDA?
//
// outerSize = 100 -> good case
// - efficient: 0.91 ms
// - high quality: 19.12 ms typical, 18.00 ms min
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

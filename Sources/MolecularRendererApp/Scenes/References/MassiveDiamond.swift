//
//  MassiveDiamond.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/12/23.
//

import Foundation
import MolecularRenderer
import OpenMM

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
//    let extraDepth: Int = 100
//    let dimensions: SIMD3<Int> = [outerSize, outerSize + extraDepth, outerSize]
    let dimensions: SIMD3<Int> = [outerSize, outerSize, outerSize]
    
    let axesOpenLower: SIMD3<Int> = [0, 0, 0]
//    let axesOpenUpper: SIMD3<Int> = [0, 1, 0]
    let axesOpenUpper: SIMD3<Int> = [0, 0, 0]
//    let plane = CrystalPlane.fcc100(outerSize, extraDepth, outerSize)
    let plane = CrystalPlane.fcc100(outerSize, outerSize, outerSize)
    
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
    
//    let latticeConstant: Float = 0.357
    let cuboid = DiamondCuboid(
      latticeConstant: 0.357,
      hydrogenBondLength: 0.109,
      plane: plane,
      hollowStart: hollowStart,
      hollowEnd: hollowEnd)
    _atoms = cuboid.atoms
    
//    for i in 0..<_atoms.count {
//      _atoms[i].origin.y -= Float(extraDepth) / 2 * latticeConstant
//    }
    
    print("Number of atoms: \(_atoms.count)")
    
  }
  
  func atoms(time: MRTimeContext) -> [MRAtom] {
    return self._atoms
  }
  
  // Find the atom closest to the center, then generate a CSV for a cumulative
  // C-C vdW energy function and cumulative compute cost w.r.t. distance. At
  // each discrete interval in radius, remove atoms from the front of the list.
  func nonbondedEnergyData() -> String {
    var minimum: SIMD3<Float> = .init(repeating: 1000)
    var maximum: SIMD3<Float> = .init(repeating: -1000)
    var carbonAtoms = _atoms.filter { $0.element == 6 }
    
    for atom in carbonAtoms {
      minimum.replace(with: atom.origin, where: atom.origin .< minimum)
      maximum.replace(with: atom.origin, where: atom.origin .> maximum)
    }
    let center = (minimum + maximum) / 2
    
    let minimumIndex = carbonAtoms.indices.min(by: {
      let firstOrigin = carbonAtoms[$0].origin
      let secondOrigin = carbonAtoms[$1].origin
      return cross_platform_distance(firstOrigin, center) < cross_platform_distance(secondOrigin, center)
    })!
    let centerAtom = carbonAtoms.remove(at: minimumIndex)
    
    carbonAtoms.sort(by: {
			let dist1 = cross_platform_distance($0.origin, centerAtom.origin)
			let dist2 = cross_platform_distance($1.origin, centerAtom.origin)
      return dist1 < dist2
    })
		var distances = carbonAtoms.map {
			cross_platform_distance($0.origin, centerAtom.origin)
		}
		distances.reverse()
		
		let bucketSizeInNm: Float = 0.01
		var totalAtoms: Int = 0
		var totalEnergyInZJ: Float = 0
		var totalForceInPN: Float = 0
		var currentDistanceInNm: Float = 0
		
		// Assuming the diamond's outer size is 30 cells, the max radius is 5 nm.
		var output: String = ""
		output += "distance (nm), energy (zJ), force (pN), accuracy, atoms\n"
//		output += "\(minimum)\n"
//		output += "\(maximum)\n"
		while currentDistanceInNm < 5 {
			currentDistanceInNm += bucketSizeInNm
			while (distances.last ?? 10) < currentDistanceInNm {
				let r = distances.removeLast()
				totalAtoms += 1
				
				let length = Float(1.960 * OpenMM_NmPerAngstrom)
				let epsilon = Float(0.037 * OpenMM_KJPerKcal)
				
				let ratio = (length / r)
				let ratioSquared = ratio * ratio
				let energyInKJPerMol = epsilon * (
					-2.25 * ratioSquared * ratioSquared * ratioSquared +
				 1.84e5 * exp(-12.00 * (r / length))
				)
				totalEnergyInZJ += 1.660578 * -energyInKJPerMol
				
				let force = epsilon * (
					-2.25 * -6 * ratioSquared * ratioSquared * ratioSquared / r +
					1.84e5 * (-12.00 / length) * exp(-12.00 * (r / length))
				)
				totalForceInPN += 1.660578 * abs(force)
			}
			output += "\(String(format: "%.2f", currentDistanceInNm)), "
			var energyToShow: Float
			if totalEnergyInZJ == 0 {
				energyToShow = -3.79734 + 1.27698
			} else {
				energyToShow = totalEnergyInZJ + 1.27698
			}
			output += "\(String(format: "%.3f", energyToShow)), "
			output += "\(String(format: "%.3f", totalForceInPN)), "
			
			let accuracy = 1 - energyToShow / (-3.79734 + 1.27698)
			output += "\(String(format: "%.3f", accuracy)), "
			output += "\(totalAtoms)\n"
		}
		
    return output
  }
}

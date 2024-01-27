//
//  HartreeFock_Experiment1.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 1/27/24.
//

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  // Rewrite this code from scratch, to accomplish the goals outlined below:
  
  // TODO: Try visualizing the higher-n s orbitals before experimenting with
  // variable-resolution orbitals.
  
  // TODO: Try an iterative procedure that finds the ideal variable-resolution
  // orbital representation. Make a good guess at required grid resolution, then
  // try again with corrections after normalization.
  //
  // Visualization:
  // - Take a 2D cross-section of the orbital.
  // - Visualize the orbital resolution with a heatmap: different atom types
  //   correspond to different resolutions.
  // - Report the decrease in number of orbital fragments when using variable
  //   resolution.
  
  // TODO: Query the expectation values with variable-resolution orbitals,
  // compare to converged results with uniform spacing.
  
  // TODO: Next, animate a sequence of multigrid transfers, showing correct
  // norm preservation. This is a different full-weighting restriction operator
  // than in the literature, because the spacing isn't uniform.
  
  var output: [Entity] = []
  let orbitals = [Orbital._1s, Orbital._2s]
  for orbital in orbitals {
    let orbitalAtoms = createAtoms(orbital: orbital)
    for atom in orbitalAtoms {
      if orbital == ._1s {
        if atom.position.x > 0 {
          output.append(atom)
        }
      } else {
        if atom.position.x <= 0 {
          output.append(atom)
        }
      }
    }
  }
  
  return output
}

enum Orbital {
  case _1s
  case _2s
}

func createAtoms(orbital: Orbital) -> [Entity] {
  struct OrbitalFragment {
    var center: SIMD3<Float>
    var width: Float
    var occupancy: Float
  }
  
  // with uniform spacing:
  //
  // spacing in Bohr | radius ratio | max charge density ratio |
  // --------------- | ------------ | ------------------------ |
  // 3.00 | 2.442 | 6.990 |
  // 2.00 | 3.181 | 18.46 |
  // 1.40 | 3.829 | 17.31 |
  // 1.00 | 4.024 | 10.99 |
  // 0.70 | 4.193 | 3.209 |
  // 0.50 | 4.164 | 8.667 |
  // 0.30 | 4.177 | 8.342 |
  // 0.20 | 4.180 | 8.235 |
  // 0.15 | 4.177 | 8.170 |
  // 0.12 | 4.168 | 8.095 |
  // 0.10 | 4.170 | 7.976 |
  // 0.09 | 4.178 | 7.911 | switching to FP64 for 100% of calculations:
  // 0.07 | 4.088 | 7.619 |    4.176 | 8.196
  // 0.05 | 4.159 | 6.858 |    4.179 | 8.192
  // 0.03 | 2.813 | 4.733 |    4.179 | 8.194
  
  // Insight: with these very large sums, FP32 rounding error is causing
  // major issues.
  // - 0.07 ->    86x86x86, 342x342x342, 25 bits
  // - 0.05 -> 120x120x120, 480x480x480, 27 bits
  // - 0.03 -> 200x200x200, 800x800x800, 29 bits
  
  // retrying with mixed precision:
  // 0.07 | 4.176 | 8.196 |
  // 0.05 | 4.179 | 8.197 |
  // 0.03 | 4.179 | 8.194 |
  //
  // moving some more FP64 parts to FP32:
  // 0.07 | 4.176 | 8.196 |
  // 0.05 | 4.179 | 8.197 |
  // 0.03 | 4.179 | 8.194 |
  //
  // using Kahan block-summation (block size 64):
  // 0.07 | 4.176 | 8.196 |
  // 0.05 | 4.179 | 8.197 |
  // 0.03 | 4.179 | 8.194 |
  //
  // using Kahan block-summation (block size 4096):
  // 0.07 | 4.176 | 8.196 |
  // 0.05 | 4.179 | 8.197 |
  // 0.03 | 4.179 | 8.194 |
  //
  // using Kahan block-summation (block size 262,144):
  // 0.07 | 4.176 | 8.195 |
  // 0.05 | 4.180 | 8.196 |
  // 0.03 | 4.180 | 8.194 |
  //
  // using Kahan block-summation (block size 16,777,216):
  // 0.10 | 4.170 | 7.977 |
  // 0.09 | 4.194 | 7.951 |
  // 0.08 | 4.162 | 7.984 |
  // 0.07 | 4.194 | 7.899 |
  // 0.06 | 4.173 | 7.914 |
  // 0.05 | 4.141 | 7.924 |
  // 0.04 | 4.125 | 7.960 |
  // 0.03 | 4.171 | 8.074 |
  // 0.02 | 4.111 | 8.169 |
  
  // this run ran out of memory and hit swap, becoming drastically slower than
  // with 0.03 Bohr spacing:
  //
  //statistics:
  //- grid: 300x300x300
  //- spacing: 0.02 -> 6.00
  //- normalization factor: 1478554.5625
  //- max occupancy: 3.863808 @ SIMD3<Float>(-0.01, -0.01, -0.01)
  //- max charge density: 482976.0
  //normalize:
  //- max occupancy: 2.6132334e-06
  //- max charge density: 0.32665417
  //- expectation radius: 1.433174967765808
  //
  //statistics:
  //- grid: 1200x1200x1200
  //- spacing: 0.02 -> 24.00
  //- normalization factor: 12076694.751464844
  //- max occupancy: 3.8635173 @ SIMD3<Float>(-0.01, -0.01, -0.01)
  //- max charge density: 482939.66
  //normalize:
  //- max occupancy: 3.199151e-07
  //- max charge density: 0.03998939
  //- expectation radius: 5.892916530370712
  //atoms: 1
  //compile time: 403970.2 ms
  
  var fragments: [OrbitalFragment] = []
  var spacing: Float = 0.02 // in Bohr
  do {
    var radiusPre: Float = 3
    if orbital == ._2s {
      radiusPre = 12
    }
    let cellRadius = Int(Float(radiusPre / spacing).rounded(.toNearestOrEven))
    let gridRadius = Float(cellRadius) * spacing
    
    for z in -cellRadius..<cellRadius {
      for y in -cellRadius..<cellRadius {
        for x in -cellRadius..<cellRadius {
          
          let center = spacing * (0.5 + SIMD3<Float>(SIMD3(x, y, z)))
          
          // Determine the density as a function of electron position.
          var radius = (center * center).sum().squareRoot()
          radius = max(radius, 0.001)
          
          let Z: Float = 1
          let r: Float = radius
          var n: Float = 1
          let a: Float = 1
          var wavefunction: Float
          
          switch orbital {
          case ._1s:
            wavefunction = exp(-Z * r / (n * a)) * (2 * Z * r / (n * a))
          case ._2s:
            n = 2
            wavefunction = exp(-Z * r / (n * a)) * (2 * Z * r / (n * a))
            
            // L_1(alpha)(x) = 1 + alpha - x
            let l: Float = 0
            let alpha = 2 * l + 1
            let L_1 = 1 + alpha - r
            wavefunction *= L_1
          }
          
          // The wavefunction is in spherical coordinates - (r, ???, ???).
          wavefunction /= r
          
          let occupancy = wavefunction * wavefunction
          let fragment = OrbitalFragment(
            center: center, width: spacing, occupancy: occupancy)
          fragments.append(fragment)
        }
      }
    }
    
    var normalizationFactor: Double = .zero
    var maxOccupancy: Float = .zero
    var maxChargeDensity: Float = .zero
    var maxOccupancyCenter: SIMD3<Float> = .zero
    
    let kahanBlockSize: Int = 16_777_216
    var kahanCounter: Int = 0
    var kahanPartial: Float = .zero
    
    for fragment in fragments {
      kahanCounter += 1
      kahanPartial += fragment.occupancy
      if kahanCounter >= kahanBlockSize {
        normalizationFactor += Double(kahanPartial)
        kahanCounter = 0
        kahanPartial = 0
      }
      
      if fragment.occupancy > maxOccupancy {
        maxOccupancyCenter = fragment.center
      }
      maxOccupancy = max(maxOccupancy, fragment.occupancy)
      
      let microvolume = fragment.width * fragment.width * fragment.width
      maxChargeDensity = max(maxChargeDensity, fragment.occupancy / microvolume)
    }
    do {
      normalizationFactor += Double(kahanPartial)
      kahanCounter = 0
      kahanPartial = 0
    }
    
    for i in fragments.indices {
      fragments[i].occupancy = fragments[i].occupancy / Float(normalizationFactor)
    }
    
    let gridDiameterRepr = String(format: "%.2f", gridRadius * 2)
    let spacingRepr = String(format: "%.2f", spacing)
    print()
    print("statistics:")
    print("- grid: \(2*cellRadius)x\(2*cellRadius)x\(2*cellRadius)")
    print("- spacing: \(spacingRepr) -> \(gridDiameterRepr)")
    print("- normalization factor: \(normalizationFactor)")
    print("- max occupancy: \(maxOccupancy) @ \(maxOccupancyCenter)")
    print("- max charge density: \(maxChargeDensity)")
    maxOccupancy /= Float(normalizationFactor)
    maxChargeDensity /= Float(normalizationFactor)
    print("normalize:")
    print("- max occupancy: \(maxOccupancy)")
    print("- max charge density: \(maxChargeDensity)")
    
    var expectationRadius: Double = .zero
    for fragment in fragments {
      let radius = (fragment.center * fragment.center).sum().squareRoot()
      kahanCounter += 1
      kahanPartial += radius * fragment.occupancy
      
      if kahanCounter >= kahanBlockSize {
        expectationRadius += Double(kahanPartial)
        kahanCounter = 0
        kahanPartial = 0
      }
    }
    do {
      expectationRadius += Double(kahanPartial)
      kahanCounter = 0
      kahanPartial = 0
    }
    print("- expectation radius: \(expectationRadius)")
  }
  
  return [Entity(position: .zero, type: .atom(.carbon))]
  
  var output: [Entity] = []
  do {
    var frame: [Entity] = []
    for fragment in fragments {
      /*
       struct OrbitalFragment {
         var center: SIMD3<Float>
         var width: Float
         var occupancy: Float
       }
       */
      
      // charge density scale: 1 e/Bohr^3 -> 300 atoms/nm^3
      // visualization scale: 1 Bohr -> 5 nanometers
      let microvolumeBohr3 = fragment.width * fragment.width * fragment.width
      let chargeDensityBohr3 = fragment.occupancy / microvolumeBohr3
      let chargeDensityNm3 = chargeDensityBohr3 * pow(1 / Float(0.0529177), 3)
//      let atomsPerNm3 = 1 * chargeDensityNm3
      var atomsPerNm3 = 300 * chargeDensityBohr3
      if orbital == ._2s {
        atomsPerNm3 *= 64
      }
      
      let visualizationScale: Float = 5
      let microvolumeNm3 = microvolumeBohr3 * visualizationScale * visualizationScale * visualizationScale
      var atomsToGenerate = microvolumeNm3 * atomsPerNm3
      
      if atomsToGenerate < 0.5 {
        if Float.random(in: 0..<1) < atomsToGenerate {
          atomsToGenerate = 1
        }
      }
      
      #if false
      if fragment.occupancy >= 0.0002 {
        print(fragment.occupancy, chargeDensityBohr3, chargeDensityNm3, atomsPerNm3)
        print("-", microvolumeBohr3, microvolumeNm3, atomsToGenerate)
        /*
         0.0002021904 0.27735308 1871.6735 83.205925
         - 0.000729 0.091125 7.5821395
         */
      }
      #endif
      
      var atomType: Element = .hydrogen
      var occupancyCutoff: Float = 1e-4
      occupancyCutoff *= pow(spacing / 0.09, 3)
      if orbital == ._2s {
        occupancyCutoff /= 64
      }
      if fragment.occupancy > occupancyCutoff {
        atomType = .phosphorus
      } else if fragment.occupancy > occupancyCutoff / 4 {
        atomType = .nitrogen
      } else if fragment.occupancy > occupancyCutoff / 16 {
        atomType = .fluorine
      } else if fragment.occupancy > occupancyCutoff / 64 {
        atomType = .carbon
      }
      
      for _ in 0..<Int(atomsToGenerate.rounded(.toNearestOrEven)) {
        let range = -fragment.width/2..<fragment.width/2
        let offset = SIMD3<Float>.random(in: range)
        let positionBohr = fragment.center + offset
        let positionNm = positionBohr * visualizationScale
        
        
        
        if positionNm.z <= 0 {
          frame.append(Entity(position: .init(positionNm), type: .atom(atomType)))
        }
      }
    }
    output = frame
  }
  
  return output
}

// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [[Entity]] {
  struct OrbitalFragment {
    var center: SIMD3<Float>
    var width: Float
    var occupancy: Float
  }
  
  var fragments: [OrbitalFragment] = []
  do {
    let spacing: Float = 0.09 // in Bohr
    let cellRadius = Int(Float(2 / spacing).rounded(.toNearestOrEven))
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
          let n: Float = 1
          let a: Float = 1
          var wavefunction = exp(-Z * r / (n * a)) * (2 * Z * r / (n * a))
          
          // The wavefunction is in spherical coordinates - (r, ???, ???).
          wavefunction /= r
          
          let occupancy = wavefunction * wavefunction
          let fragment = OrbitalFragment(
            center: center, width: spacing, occupancy: occupancy)
          fragments.append(fragment)
        }
      }
    }
    
    var normalizationFactor: Float = .zero
    var maxOccupancy: Float = .zero
    var maxChargeDensity: Float = .zero
    var maxOccupancyCenter: SIMD3<Float> = .zero
    for fragment in fragments {
      normalizationFactor += fragment.occupancy
      if fragment.occupancy > maxOccupancy {
        maxOccupancyCenter = fragment.center
      }
      maxOccupancy = max(maxOccupancy, fragment.occupancy)
      
      let microvolume = fragment.width * fragment.width * fragment.width
      maxChargeDensity = max(maxChargeDensity, fragment.occupancy / microvolume)
    }
    
    for i in fragments.indices {
      fragments[i].occupancy /= normalizationFactor
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
    maxOccupancy /= normalizationFactor
    maxChargeDensity /= normalizationFactor
    print("normalize:")
    print("- max occupancy: \(maxOccupancy)")
    print("- max charge density: \(maxChargeDensity)")
  }
  
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
  
  var output: [[Entity]] = []
  for _ in 0..<1 {
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
      let atomsPerNm3 = 300 * chargeDensityBohr3
      
      let visualizationScale: Float = 5
      let microvolumeNm3 = microvolumeBohr3 * visualizationScale * visualizationScale * visualizationScale
      let atomsToGenerate = max(1, microvolumeNm3 * atomsPerNm3)
      
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
      if fragment.occupancy > 1e-4 {
        atomType = .phosphorus
      } else if fragment.occupancy > 1e-4 / 8 {
        atomType = .nitrogen
      } else if fragment.occupancy > 1e-4 / 64 {
        atomType = .fluorine
      } else if fragment.occupancy > 1e-4 / 512 {
        atomType = .germanium
      }
      
      for _ in 0..<Int(atomsToGenerate.rounded(.toNearestOrEven)) {
        let range = -fragment.width/2..<fragment.width/2
        let offset = SIMD3<Float>.random(in: range)
        let positionBohr = fragment.center + offset
        let positionNm = positionBohr * visualizationScale
        
        
        
        if positionNm.z <= 0 {
          frame.append(Entity(position: positionNm, type: .atom(atomType)))
        }
      }
    }
    output.append(frame)
  }
  
  return output
}

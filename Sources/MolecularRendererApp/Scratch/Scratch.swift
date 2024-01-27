// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  // Solve the Hartree equation with finite-differencing, visualizing the
  // evolution of the 2s orbital into the 1s orbital. Then, experiment with
  // multigrids.
  //
  // Defer investigation of more complex things (variable-resolution orbitals,
  // multi-electron orthogonalization, exchange-correlation, FP32) to a future
  // design iteration. The code may be rewritten from scratch before that
  // stuff is investigated.
  //
  // Work breakdown structure:
  // - Start with just the Hartree term. This doesn't require
  //   finite-differencing.
  //   - Observe how the solver behaves, e.g. something reminiscent of 2s
  //     evolving into 1s. Is there "critical slowing down" with finer
  //     resolution?
  // - Add 2nd-order finite-differencing for the kinetic term.
  // - Investigate multigrids for the Poisson solver, with an interpolation
  //   scheme suitable for variable-resolution orbitals.
  // - Investigate multigrids for the eigensolver.
  
  struct OrbitalFragment {
    // in Bohr, with 0.2 Å spacing
    var position: SIMD3<Double>
    
    // density times microvolume, easily confused with just density
    var occupancy: Double
  }
  
  // Create a 30x30x30 grid of orbital fragments.
  var fragments: [OrbitalFragment] = []
  for xIndex in -25..<25 {
    for yIndex in -25..<25 {
      for zIndex in -25..<25 {
        var position = SIMD3<Double>(
          Double(xIndex),
          Double(yIndex),
          Double(zIndex))
        position += 0.5
        position *= 0.020
        position /= 0.0529177
        
        if xIndex == -20 && yIndex == -20 {
          print(position)
        }
      }
    }
  }
  
  return [Entity(position: .zero, type: .atom(.carbon))]
}

// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // Demonstrate transmission of a clock signal in one of the 2 available
  // directions. It should demonstrate the sequence of clock phases expected in
  // the full ALU. Measure how short the switching time can be.
  // - Take at least one screenshot to document this experiment.
  
  var system = System()
  system.minimize()
  system.initializeRigidBodies()
  
  // Start with a short rigid body dynamics simulation, with the housing and
  // drive wall positionally constrained. Test whether the rods fall into their
  // lowest-energy state.
  
  // Demonstrate rigid body energy minimization with FIRE. This is a proof of
  // concept for the DFT simulator. Use INQ as a reference, then incorporate the
  // improvements from FIRE 2.0 and ABC.
  
  let topologies = system.getTopologies()
  let output = topologies.flatMap(\.atoms)
  return output
}

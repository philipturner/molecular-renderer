import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Compile a design for a half adder. Energy-minimize the housing with
// positional constraints on the bulk atoms. Place the adder in the scene.
// Test whether it works in a constrained MD simulation, but delete the code
// and don't worry about animating it right now.
//
// Extract each logic rod, remove the hydrogens on one side, and arrange the
// finished products on the silicon surface. Compile a complete build sequence
// for every rod.

func createGeometry() -> [MM4RigidBody] {
  let halfAdder = HalfAdder()
  let output = halfAdder.rigidBodies
  
  var forceFieldParameters = output[0].parameters
  for rigidBody in output[1...] {
    let parameters = rigidBody.parameters
    forceFieldParameters.append(contentsOf: parameters)
  }
  let atomCount = forceFieldParameters.atoms.count
  
  var bulkAtomCount: Int = .zero
  for atomID in forceFieldParameters.atoms.indices {
    let centerType = forceFieldParameters.atoms.centerTypes[atomID]
    if centerType == .quaternary {
      bulkAtomCount += 1
    }
  }
  
  // housing + rods
  // total atoms: 57846
  // bulk atoms: 27618
  // surface atoms: 30228
  //
  // housing
  // total atoms: 46678
  // bulk atoms: 24122
  // surface atoms: 22556
  //
  // housing surface atoms: 22556 / 57846 = 39%
  print(atomCount)
  print(bulkAtomCount)
  
  return output
}

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  // Compile an axle, and a sheet of diamond that will curl around it.
  let sheetPart = SheetPart()
  let axlePart = AxlePart()
  
  // Energy minimization procedure.
  var simulation = GenericSimulation(rigidBodies: [
    sheetPart.rigidBody, axlePart.rigidBody
  ])
  //  simulation.withForceField {
  //    $0.minimize()
  //  }
  //  simulation.rigidBodies[1].centerOfMass.z -= 1.9
  //  simulation.withForceField {
  //    $0.minimize()
  //  }
  
  // Prepare for rendering.
  for rigidBodyID in simulation.rigidBodies.indices {
    var rigidBody = simulation.rigidBodies[rigidBodyID]
    
    // 0.3567 is the lattice constant of cubic diamond (in nm).
    rigidBody.centerOfMass += SIMD3(-20, -20, 0) * 0.3567
    rigidBody.centerOfMass += SIMD3(0, 0, -35) * 0.3567
    simulation.rigidBodies[rigidBodyID] = rigidBody
  }
  
  return simulation.rigidBodies
}

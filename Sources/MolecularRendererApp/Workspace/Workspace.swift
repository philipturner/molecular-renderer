import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  let inputUnit = CLAInputUnit()
  let generateUnit = CLAGenerateUnit()
  let propagateUnit = CLAPropagateUnit()
  
  var rods: [Rod] = []
  rods.append(propagateUnit.signal[0])
  rods.append(propagateUnit.probe[0]!)
  
  let initRigidBodies = rods.map { $0.rigidBody }
  var simulation = GenericSimulation(rigidBodies: initRigidBodies)
  
  simulation.withForceField { forceField in
    for offsetID in -10...10 {
      var copies = rods.map { $0.rigidBody }
      let offset = Double(offsetID) * 0.25 * 0.3567
      copies[1].centerOfMass.z += offset
      
      forceField.positions = copies.flatMap(\.positions)
      print(Double(offsetID) * 0.25, forceField.energy.potential)
    }
  }
  
  return rods.map { $0.rigidBody }
}

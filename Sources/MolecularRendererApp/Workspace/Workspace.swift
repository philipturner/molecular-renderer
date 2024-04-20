import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  let inputUnit = CLAInputUnit()
  let generateUnit = CLAGenerateUnit()
  
  var rods: [Rod] = []
  rods.append(generateUnit.signal[2])
  rods.append(generateUnit.probe[2]!)
  
  var forceFieldParams = rods[0].rigidBody.parameters
  forceFieldParams.append(contentsOf: rods[1].rigidBody.parameters)
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = forceFieldParams
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = rods.flatMap(\.rigidBody.positions)
  
  for offsetZ in -10...10 {
    let deltaZ = Double(offsetZ) * 0.25
    
    var copies = rods
    copies[1].rigidBody.centerOfMass.z += deltaZ * 0.3567
    forceField.positions = copies.flatMap(\.rigidBody.positions)
    print(deltaZ, forceField.energy.potential)
    
    /*
     -0.5 25972.2900390625
     -0.25 25925.47802734375
     0.0 25856.48583984375
     0.25 26481.03125
     0.5 39374.874755859375
     */
    
    /*
     -0.5 25972.411865234375
     -0.25 25925.671875
     0.0 25856.66259765625
     0.25 26487.083740234375
     0.5 39532.663330078125
     */
  }
  
  exit(0)
}

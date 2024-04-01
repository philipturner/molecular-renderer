import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  let flywheel = Flywheel()
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = flywheel.rigidBody.parameters
  forceFieldDesc.integrator = .multipleTimeStep
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = flywheel.rigidBody.positions
  
  print(forceField.energy.potential)
  
  // 132396232.265625
  //   3993967.810546875
  //   2308207.91796875
  
  let forces = forceField.forces
  var maxForceMagnitude: Float = .zero
  for force in forces {
    let magnitude = (force * force).sum().squareRoot()
    maxForceMagnitude = max(maxForceMagnitude, magnitude)
    if magnitude.isInfinite || magnitude.isNaN {
      print("NAN force")
    }
  }
  print(maxForceMagnitude)
  
  forceField.minimize()
  print(forceField.energy.potential)
  
  // -538450.728515625
  // -583069.953125
  
  exit(0)
}

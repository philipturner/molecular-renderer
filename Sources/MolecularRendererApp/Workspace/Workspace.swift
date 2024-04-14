import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  let driveSystem = DriveSystem()
  let housing = driveSystem.housing
  
  var minPosition: SIMD3<Float> = .init(repeating: .greatestFiniteMagnitude)
  var maxPosition: SIMD3<Float> = .init(repeating: -.greatestFiniteMagnitude)
  for position in housing.rigidBody.positions {
    minPosition.replace(with: position, where: position .< minPosition)
    maxPosition.replace(with: position, where: position .> maxPosition)
  }
  
  print()
  print(minPosition)
  print(maxPosition)
  print(housing.rigidBody.centerOfMass)
  
  let flywheel = driveSystem.flywheel
  
  print()
  print(flywheel.rigidBody.centerOfMass)
  print(flywheel.rigidBody.principalAxes)
  print(flywheel.rigidBody.momentOfInertia)
  print(flywheel.rigidBody.mass)
  print(flywheel.knobAtomIDs.count)
  
  /*
   SIMD3<Float>(-16.171835, -3.6482308, -2.309098)
   SIMD3<Float>(16.092937, 3.6475387, 2.8464727)
   SIMD3<Double>(0.0, 0.0, 0.0)
   
   SIMD3<Double>(-12.541997445614843, 0.0003639226778950899, 2.2477964993919026)
   (
   SIMD3<Double>(0.0038007343439917978, -0.00015094941917463643, 0.9999927657901928),
   SIMD3<Double>(0.017579776424421312, 0.9998454602518669, 8.411063994743733e-05),
   SIMD3<Double>(-0.9998382398564849, 0.017579329566432354, 0.003802800636504043)
   )
   SIMD3<Double>(12061859.1956632, 6249246.2721232055, 6212125.687487029)
   631910.4663085938
   204
   */
  
  /*
   SIMD3<Float>(-16.171835, -3.6482308, -2.309098)
   SIMD3<Float>(16.092937, 3.6475387, 2.8464727)
   SIMD3<Double>(0.0, 0.0, 0.0)

   SIMD3<Double>(-12.533657550969775, 3.10535072451934e-05, 2.221963486648106)
   (SIMD3<Double>(0.0018359273001002658, -7.271239605371843e-05, 0.9999983120405035), SIMD3<Double>(0.05723677523173216, 0.9983606314881961, -3.248941941725368e-05), SIMD3<Double>(-0.9983589439335038, 0.05723673826658593, 0.0018370793617640076))
   SIMD3<Double>(32177036.864855755, 16592956.986039216, 16541347.065120652)
   1620560.197265625
   204
   */
  
  return driveSystem.rigidBodies
}

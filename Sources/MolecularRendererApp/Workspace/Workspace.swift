import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  // TODO: Investigate the kinetic energies at different keyframes of the cycle.
  let driveSystem = DriveSystem()
  
  func findKeyPoint(
    rigidBody: MM4RigidBody, knobAtomIDs: [UInt32]
  ) -> SIMD3<Float> {
    var accumulator: SIMD3<Float> = .zero
    for atomID in knobAtomIDs {
      let position = rigidBody.positions[Int(atomID)]
      accumulator += position
    }
    accumulator /= Float(knobAtomIDs.count)
    accumulator.z = .zero
    return accumulator
  }
  
  func findCenterOfMass(
    rigidBody: MM4RigidBody, knobAtomIDs: [UInt32]
  ) -> SIMD3<Float> {
    var knobAccumulator: SIMD3<Float> = .zero
    var knobMass: Float = .zero
    for atomID in knobAtomIDs {
      let position = rigidBody.positions[Int(atomID)]
      let mass = rigidBody.parameters.atoms.masses[Int(atomID)]
      knobAccumulator += position * mass
      knobMass += mass
    }
    
    var rigidBodyMass = Float(rigidBody.mass)
    var rigidBodyAccumulator = rigidBodyMass * SIMD3<Float>(
      rigidBody.centerOfMass)
    rigidBodyAccumulator -= knobAccumulator
    rigidBodyMass -= knobMass
    return rigidBodyAccumulator / rigidBodyMass
  }
  
  let flywheel = driveSystem.flywheel
  let connectingRod = driveSystem.connectingRod
  let piston = driveSystem.piston
  let point0 = findCenterOfMass(
    rigidBody: flywheel.rigidBody, knobAtomIDs: flywheel.knobAtomIDs)
  var point1 = findKeyPoint(
    rigidBody: flywheel.rigidBody, knobAtomIDs: flywheel.knobAtomIDs)
  var point2 = findKeyPoint(
    rigidBody: piston.rigidBody, knobAtomIDs: piston.knobAtomIDs)
  print("point 0:", point0)
  print("point 1:", point1)
  print("point 2:", point2)
  print("connecting rod center:", connectingRod.rigidBody.centerOfMass)
  
  let r = ((point1 - point0) * (point1 - point0)).sum().squareRoot()
  let l = ((point2 - point1) * (point2 - point1)).sum().squareRoot()
  print("r:", r)
  print("l:", l)
  print(flywheel.rigidBody.mass)
  print(connectingRod.rigidBody.mass)
  print(piston.rigidBody.mass)
  
  print(findCenterOfMass(rigidBody: flywheel.rigidBody, knobAtomIDs: flywheel.knobAtomIDs))
  print(connectingRod.rigidBody.centerOfMass)
  
  print()
  print(flywheel.rigidBody.principalAxes)
  print(connectingRod.rigidBody.principalAxes)
  print()
  print(flywheel.rigidBody.momentOfInertia)
  print(connectingRod.rigidBody.momentOfInertia)
  
  /*
   
   (SIMD3<Double>(0.0038007343439917978, -0.00015094941917463643, 0.9999927657901928), SIMD3<Double>(0.017579776424421312, 0.9998454602518669, 8.411063994743733e-05), SIMD3<Double>(-0.9998382398564849, 0.017579329566432354, 0.003802800636504043))
   
   (SIMD3<Double>(0.00016627176688619033, -0.012565368972819643, 0.9999210388107035), SIMD3<Double>(-0.0010841326065681243, 0.9999204627421728, 0.012565542008613147), SIMD3<Double>(-0.9999993985049145, -0.0010861362970398093, 0.00015263601586880493))
   
   */
  
  exit(0)
}

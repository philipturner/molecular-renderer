import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  // TODO: Jump right into experiments measuring flywheel system performance.
  // Do not waste time creating a serializer.
  //
  // Set up the process for determining r and l. It can be scripted without
  // the high-latency minimization, then recompiled with minimization included.
  
  var driveSystem = DriveSystem()
  
  let flywheelData = DriveSystemPartData(source: driveSystem.flywheel)
  let pistonData = DriveSystemPartData(source: driveSystem.piston)
  let rotationAxis = driveSystem.flywheel.rigidBody.principalAxes.0
  guard rotationAxis.z > 0.999 else {
    fatalError("Flywheel was not aligned with expected reference frame.")
  }
  
  var rVector = flywheelData.knobCenter - flywheelData.bodyCenter
  var lVector = flywheelData.knobCenter - pistonData.knobCenter
  rVector -= (rVector * rotationAxis).sum() * rotationAxis
  lVector -= (lVector * rotationAxis).sum() * rotationAxis
  let r = (rVector * rVector).sum().squareRoot()
  let l = (lVector * lVector).sum().squareRoot()
  print("r:", r)
  print("l:", l)
  
  let frequencyInGHz: Double = 10.0
  let ω = frequencyInGHz * 0.001 * (2 * .pi)
  print("ω_f:", ω)
  
  
  
  exit(0)
}

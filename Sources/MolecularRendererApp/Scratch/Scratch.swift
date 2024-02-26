// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [[Entity]] {
  // Demonstrate transmission of a clock signal in one of the 2 available
  // directions. It should demonstrate the sequence of clock phases expected in
  // the full ALU. Measure how short the switching time can be.
  // - Take at least one screenshot to document this experiment.
  
  var system = System()
  system.minimize()
  system.initializeRigidBodies()
  
  // Set up the system for simulation.
  for rodID in system.rods.indices {
    system.rods[rodID].rigidBody!.centerOfMass += SIMD3(0, 0, -0.7)
  }
  
  var rigidBodies: [MM4RigidBody] = []
  rigidBodies.append(system.housing.rigidBody!)
  for rod in system.rods {
    rigidBodies.append(rod.rigidBody!)
  }
  rigidBodies.append(system.driveWall.rigidBody!)
  
  var fire = FIRE()
  fire.anchors = [0, 5]
  fire.rigidBodies = rigidBodies
  let result = fire.minimize()
  return result.frames
}

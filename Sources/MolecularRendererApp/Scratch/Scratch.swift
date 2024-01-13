// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

func createNanoRobot() -> [[Entity]] {
  // TODO: Add some crystolecules from the built site to the center frame.
  // When the boolean for 'directionIn' is true, materialize them into the
  // simulator. Ensure the crystolecule stays between the grippers. Then, give
  // the build plate a velocity. Have it fly away for another ~70 frames.
  //
  // After this is done, double the time taken for the animation. Double the
  // number of frames presented to the user.
  
  // Video structure:
  // - looking at workspace
  //   - screenshot from YouTube video behing Xcode window
  // - video the entire scene compiling in 15 seconds
  //   - zoom in on the compile time
  // - video the window on the MacBook
  let robotFrame = RobotFrame()
  return robotFrame.animationFrames
}

extension RobotFrame {
  mutating func simulateGrippingMotion(directionIn: Bool) {
    var centerPieceMinX: Float = .greatestFiniteMagnitude
    var centerPieceMaxX: Float = -.greatestFiniteMagnitude
    for atom in centerPiece.topology.atoms {
      let x = atom.position.x
      centerPieceMaxX = max(centerPieceMaxX, x)
      centerPieceMinX = min(centerPieceMinX, x)
    }
    
    var sceneParameters: MM4Parameters?
    for gripper in grippers {
      var parameters = gripper.rigidBody!.parameters
      for i in parameters.atoms.indices {
        if parameters.atoms.masses[i] == 0 {
          parameters.atoms.masses[i] = 12.011 * Float(MM4YgPerAmu)
        }
      }
      if sceneParameters == nil {
        sceneParameters = parameters
      } else {
        sceneParameters!.append(contentsOf: parameters)
      }
    }
    sceneParameters!.append(contentsOf: centerPiece.parameters!)
    
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = sceneParameters
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    var initialPositions: [SIMD3<Float>] = []
    for gripper in grippers {
      initialPositions += gripper.rigidBody!.positions
    }
    initialPositions += centerPiece.topology.atoms.map(\.position)
    forceField.positions = initialPositions
    
    var externalForces: [SIMD3<Float>] = []
    var velocities: [SIMD3<Float>] = []
    for gripper in grippers {
      for position in gripper.rigidBody!.positions {
        if position.x > centerPieceMinX && position.x < centerPieceMaxX {
          externalForces.append(SIMD3(0, directionIn ? +1 : -1, 0))
          velocities.append(SIMD3(0, 0, 0))
        } else {
          externalForces.append(SIMD3(0, directionIn ? -1 : 1, 0))
          velocities.append(SIMD3(0, 0, 0))
        }
      }
    }
    for _ in centerPiece.topology.atoms.indices {
      externalForces.append(SIMD3(0, 0, 0))
      velocities.append(SIMD3(0, 0, 0))
    }
    forceField.externalForces = externalForces
    forceField.velocities = velocities
    
    print("frame=0")
    for frameID in 0...70 {
      // Add a thermostat to all atoms with X inside the desired range.
      if frameID % 10 == 0 {
        var newVelocities = forceField.velocities
        for i in forceField.positions.indices {
          let position = forceField.positions[i]
          if position.x > centerPieceMinX && position.x < centerPieceMaxX {
            newVelocities[i] = .zero
          }
        }
        forceField.velocities = newVelocities
      }
      
      // NOTE: Never minimize when there are external forces!
      let step: Double = 0.200
      forceField.simulate(time: step)
      print("frame=\(frameID), time=\(String(format: "%.3f", Double(frameID) * step))")
      
      var cursor: Int = 0
      var frame: [Entity] = []
      for gripperID in grippers.indices {
        let gripper = grippers[gripperID]
        let topology = gripper.topology
        let range = cursor..<cursor + topology.atoms.count
        let positions = Array(forceField.positions[range])
        for i in topology.atoms.indices {
          var entity = topology.atoms[i]
          entity.position = positions[i]
          frame.append(entity)
        }
        cursor = range.endIndex
        
        if frameID == 70 {
          var rigidBodyDesc = MM4RigidBodyDescriptor()
          rigidBodyDesc.parameters = grippers[gripperID].rigidBody!.parameters
          rigidBodyDesc.positions = positions
          let rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
          grippers[gripperID].rigidBody = rigidBody
        }
      }
      do {
        let topology = centerPiece.topology
        let range = cursor..<cursor + topology.atoms.count
        let positions = Array(forceField.positions[range])
        for i in topology.atoms.indices {
          var entity = topology.atoms[i]
          entity.position = positions[i]
          if frameID == 70 {
            centerPiece.topology.atoms[i].position = entity.position
          }
          frame.append(entity)
        }
        cursor = range.endIndex
      }
      animationFrames.append(frame)
    }
  }
}

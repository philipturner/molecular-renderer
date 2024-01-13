// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

func createNanoRobot() -> [[Entity]] {
  // Video structure:
  // - looking at workspace
  //   - screenshot from YouTube video behing Xcode window
  // - video the entire scene compiling in 15 seconds
  //   - zoom in on the compile time
  // - video the window on the MacBook
  // - after the animation is done, move around in the scene
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
    
    if directionIn {
      sceneParameters!.append(contentsOf: buildSite.molecule.parameters)
      sceneParameters!.append(contentsOf: buildSite.plate.parameters)
    }
    
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = sceneParameters
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    var initialPositions: [SIMD3<Float>] = []
    for gripper in grippers {
      initialPositions += gripper.rigidBody!.positions
    }
    initialPositions += centerPiece.topology.atoms.map(\.position)
    if directionIn {
      initialPositions += buildSite.molecule.positions
      initialPositions += buildSite.plate.positions
    }
    
    forceField.positions = initialPositions
    

    
    var externalForces: [SIMD3<Float>] = []
    var velocities: [SIMD3<Float>] = []
    for gripper in grippers {
      for position in gripper.rigidBody!.positions {
        if position.x > centerPieceMinX && position.x < centerPieceMaxX {
          externalForces.append(SIMD3(0, directionIn ? +2 : -1, 0))
          velocities.append(SIMD3(0, 0, 0))
        } else {
          externalForces.append(SIMD3(0, directionIn ? -2 : 1, 0))
          velocities.append(SIMD3(0, 0, 0))
        }
      }
    }
    for _ in centerPiece.topology.atoms.indices {
      externalForces.append(SIMD3(0, 0, 0))
      velocities.append(SIMD3(0, 0, 0))
    }
    
    if directionIn {
      for _ in 0..<(buildSite.molecule.positions.count + buildSite.plate.positions.count) {
        externalForces.append(SIMD3(0, 0, 0))
        velocities.append(SIMD3(0, 0, 0))
      }
    }
    
    forceField.externalForces = externalForces
    forceField.velocities = velocities
    
    
    print("frame=0")
    let maxFrame = (directionIn ? 100 : 50)
    for frameID in 0...maxFrame {
      // Add a thermostat to all atoms with X inside the desired range.
      if frameID % 5 == 0 {
        var newVelocities = forceField.velocities
        for i in forceField.positions.indices {
          let position = forceField.positions[i]
          if position.x > centerPieceMinX && position.x < centerPieceMaxX {
            newVelocities[i] = .zero
          }
        }
        if directionIn && frameID >= 50 {
          let start = newVelocities.count - buildSite.plate.positions.count
          for i in start..<newVelocities.count {
            newVelocities[i] = SIMD3(0, -0.100, 0)
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
        
        if frameID == 50 {
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
          if frameID == 50 {
            centerPiece.topology.atoms[i].position = entity.position
          }
          frame.append(entity)
        }
        cursor = range.endIndex
      }
      if directionIn {
        for rigidBody in [buildSite.molecule, buildSite.plate] {
          for i in rigidBody.parameters.atoms.indices {
            let position = forceField.positions[cursor]
            cursor += 1
            let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[i]
            let entity = Entity(storage: SIMD4(position, Float(atomicNumber)))
            frame.append(entity)
          }
        }
      }
      if frameID == 0 {
        animationFrames.append(frame)
      } else {
        let lastFrame = animationFrames.last!
        for keyFrame in 1...3 {
          var interpolatedFrame: [Entity] = []
          for i in lastFrame.indices {
            let last = lastFrame[i]
            let next = frame[i]
            let closenessLast = 1 - Float(keyFrame) / 3
            let closenessNext = Float(keyFrame) / 3
            let position = last.position * closenessLast + next.position * closenessNext
            interpolatedFrame.append(Entity(position: position, type: next.type))
          }
          animationFrames.append(interpolatedFrame)
        }
      }
    }
    
    if directionIn {
      for _ in 0..<480 {
        // Set the position to what happens with -0.100 velocity and
        // 0.200 / keyFrames step.
        var nextFrame = animationFrames.last!
        let start = nextFrame.count - buildSite.plate.positions.count
        for i in start..<nextFrame.count {
          nextFrame[i].position += SIMD3(0, -0.100 * 0.200 / 3, 0)
        }
        animationFrames.append(nextFrame)
      }
    }
  }
}

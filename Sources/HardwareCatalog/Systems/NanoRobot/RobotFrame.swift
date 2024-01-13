//
//  RobotFrame.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/11/24.
//

import HDL
import MM4

struct RobotFrame {
  var grippers: [RobotGripper]
  
  var animationFrames: [[Entity]] = []
  
  init() {
    let robotGripper1 = RobotGripper()
    grippers = [robotGripper1, robotGripper1]
    grippers[1].rigidBody!.centerOfMass.x += 2.8
    grippers[1].rigidBody!.rotate(angle: .pi, axis: [0, 1, 0])
    
    displayStaticFrame()
    simulateGripperJoining()
  }
  
  mutating func displayStaticFrame() {
    var frame: [Entity] = []
    for gripper in grippers {
      let rigidBody = gripper.rigidBody!
      let topology = gripper.topology
      for i in topology.atoms.indices {
        var entity = topology.atoms[i]
        entity.position = rigidBody.positions[i]
        frame.append(entity)
      }
    }
    animationFrames.append(frame)
  }
  
  mutating func simulateGripperJoining() {
    
  }
}

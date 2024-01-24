// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [[Entity]] {
  let xorGate = XORGate()
  
  var topologies: [Topology] = []
  for housingUnit in xorGate.housingUnits {
    topologies.append(housingUnit.topology)
  }
  for logicRod in xorGate.logicRods {
    topologies.append(logicRod.topology)
  }
  var atoms = topologies.flatMap(\.atoms)
  
  // TODO: Test the forward execution pass of two I/O pairs with MD simulations.
  // One pair outputs 0; another outputs 1. Finally, use RBD to simulate how
  // logic rods should move with each I/O pair and reversible clocking.
  
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = []
  paramsDesc.bonds = []
  var sceneParameters = try! MM4Parameters(descriptor: paramsDesc)
  for topology in topologies {
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    sceneParameters.append(contentsOf: parameters)
  }
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.integrator = .multipleTimeStep
  forceFieldDesc.parameters = sceneParameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = atoms.map(\.position)
  forceField.minimize()
  
  for i in atoms.indices {
    atoms[i].position = forceField.positions[i]
  }
  
  var animation: [[Entity]] = [atoms]
  for frameID in 0..<480 {
    if frameID % 10 == 0 {
      print("frame=\(frameID)")
    }
    forceField.simulate(time: 0.100)
    for i in atoms.indices {
      atoms[i].position = forceField.positions[i]
    }
    animation.append(atoms)
  }
  
  return animation
}

struct XORGate {
  var housingUnits: [LogicHousing] = []
  
  // rod 0 = input 0
  // rod 1 = input 1
  // rod 2 = output 0
  // rod 3 = intermediate 0
  // rod 4 = intermediate 1
  var logicRods: [LogicRod] = []
  
  init() {
    createHousingUnits()
    createLogicRods()
  }
  
  mutating func createHousingUnits() {
    for x in 0...2 {
      for y in 0...1 {
        var descriptor = LogicHousingDescriptor()
        descriptor.grooves.insert(.lowerRodFrontBack)
        descriptor.grooves.insert(.upperRodLeftRight)
        if (y * 3 + x) % 2 == 0 {
          descriptor.grooves.insert(.lowerLeft)
          descriptor.grooves.insert(.lowerRight)
          descriptor.grooves.insert(.upperFront)
          descriptor.grooves.insert(.upperBack)
        } else {
          descriptor.grooves.insert(.lowerFront)
          descriptor.grooves.insert(.lowerBack)
          descriptor.grooves.insert(.upperLeft)
          descriptor.grooves.insert(.upperRight)
        }
        if x == 0 {
          descriptor.grooves.remove(.lowerLeft)
          descriptor.grooves.remove(.upperLeft)
        } else if x == 2 {
          descriptor.grooves.remove(.lowerRight)
          descriptor.grooves.remove(.upperRight)
        }
        if y == 0 {
          descriptor.grooves.remove(.lowerBack)
          descriptor.grooves.remove(.upperBack)
        } else if y == 1 {
          descriptor.grooves.remove(.lowerFront)
          descriptor.grooves.remove(.upperFront)
        }
        var housing = LogicHousing(descriptor: descriptor)
        
        let latticeConstant = Constant(.square) { .elemental(.carbon) }
        var translation: SIMD3<Float> = .zero
        translation.x += Float(x) * 7.5 * latticeConstant
        translation.z += Float(y) * 7.5 * latticeConstant
        for i in housing.topology.atoms.indices {
          housing.topology.atoms[i].position += translation
        }
        housingUnits.append(housing)
      }
    }
  }
  
  mutating func createLogicRods() {
    // Rods oriented in the front->back direction.
    for rodID in 0...2 {
      var descriptor = LogicRodDescriptor()
      descriptor.length = 31
      
      if rodID == 0 || rodID == 1 {
        descriptor.indentations = [5..<11, 21..<27]
      } else {
        descriptor.indentations = [11..<16, 21..<27]
      }
      
      // Orient the rod.
      var logicRod = LogicRod(descriptor: descriptor)
      for i in logicRod.topology.atoms.indices {
        var atom = logicRod.topology.atoms[i]
        atom.position = SIMD3(atom.position.z, atom.position.y, atom.position.x)
        atom.position.z = -atom.position.z
        logicRod.topology.atoms[i] = atom
      }
      
      // Shift the rod along the X axis.
      let latticeConstant = Constant(.square) { .elemental(.carbon) }
      var translation: SIMD3<Float> = .zero
      translation.x += Float(rodID) * 7.5 * latticeConstant
      
      // Align the rod with the housing.
      translation.x += 0.025 + 3 * latticeConstant
      translation.y += -0.050 + 2.5 * latticeConstant
      translation.z += 21 * latticeConstant
      for i in logicRod.topology.atoms.indices {
        logicRod.topology.atoms[i].position += translation
      }
      logicRods.append(logicRod)
    }
    
    // Rods oriented in the left->right direction.
    for rodID in 3...4 {
      var descriptor = LogicRodDescriptor()
      descriptor.length = 42
      descriptor.indentations = [11..<16, 21..<27, 32..<37]
      
      // Orient the rod.
      var logicRod = LogicRod(descriptor: descriptor)
      for i in logicRod.topology.atoms.indices {
        var atom = logicRod.topology.atoms[i]
        atom.position.y = -atom.position.y
        logicRod.topology.atoms[i] = atom
      }
      
      // Shift the rod along the Z axis.
      
      let latticeConstant = Constant(.square) { .elemental(.carbon) }
      var translation: SIMD3<Float> = .zero
      translation.z += Float(rodID - 3) * 7.5 * latticeConstant
      
      // Align the rod with the housing.
      translation.z += 0.025 + 3 * latticeConstant
      translation.y += 0.040 + 7.5 * latticeConstant
      translation.x -= 5.5 * latticeConstant
      for i in logicRod.topology.atoms.indices {
        logicRod.topology.atoms[i].position += translation
      }
      logicRods.append(logicRod)
    }
  }
}

//
//  System.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 2/25/24.
//

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

struct System {
  var housing: Housing
  var rods: [Rod] = []
  var driveWall: DriveWall
  
  init() {
    housing = Housing()
    for xIndex in 0..<2 {
      for yIndex in 0..<2 {
        var descriptor = RodDescriptor()
        descriptor.xIndex = xIndex
        descriptor.yIndex = yIndex
        let rod = Rod(descriptor: descriptor)
        rods.append(rod)
      }
    }
    driveWall = DriveWall()
  }
  
  func getTopologies() -> [Topology] {
    var topologies: [Topology] = []
    topologies.append(housing.topology)
    for rod in rods {
      topologies.append(rod.topology)
    }
    topologies.append(driveWall.topology)
    return topologies
  }
}

extension System {
  mutating func minimize() {
    let topologies = getTopologies()
    var systemAtoms = topologies.flatMap(\.atoms)
    
    let minimizer = createMinimizer(topologies: topologies)
    minimizer.positions = systemAtoms.map(\.position)
    minimizer.minimize()
    for i in systemAtoms.indices {
      let position = minimizer.positions[i]
      systemAtoms[i].position = position
    }
    
    var cursor = 0
    func appendAtoms(to topology: inout Topology) {
      let range = cursor..<cursor + topology.atoms.count
      let subSequence = Array(systemAtoms[range])
      cursor += topology.atoms.count
      
      topology.atoms = subSequence
    }
    appendAtoms(to: &housing.topology)
    appendAtoms(to: &rods[0].topology)
    appendAtoms(to: &rods[1].topology)
    appendAtoms(to: &rods[2].topology)
    appendAtoms(to: &rods[3].topology)
    appendAtoms(to: &driveWall.topology)
  }
  
  private func createMinimizer(topologies: [Topology]) -> MM4ForceField {
    var emptyParamsDesc = MM4ParametersDescriptor()
    emptyParamsDesc.atomicNumbers = []
    emptyParamsDesc.bonds = []
    var systemParameters = try! MM4Parameters(descriptor: emptyParamsDesc)
    
    for topology in topologies {
      var paramsDesc = MM4ParametersDescriptor()
      paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
      paramsDesc.bonds = topology.bonds
      var parameters = try! MM4Parameters(descriptor: paramsDesc)
      for i in parameters.atoms.indices {
        if parameters.atoms.ringTypes[i] == 5 {
          // pass
        } else if parameters.atoms.centerTypes[i] == .quaternary {
          parameters.atoms.masses[i] = 0
        }
      }
      systemParameters.append(contentsOf: parameters)
    }
    
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = systemParameters
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    return forceField
  }
  
  mutating func initializeRigidBodies() {
    let topologies = getTopologies()
    var rigidBodies: [MM4RigidBody] = []
    
    for rigidBodyID in topologies.indices {
      let topology = topologies[rigidBodyID]
      var paramsDesc = MM4ParametersDescriptor()
      paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
      paramsDesc.bonds = topology.bonds
      paramsDesc.forces = [.nonbonded]
      let parameters = try! MM4Parameters(descriptor: paramsDesc)
      
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = parameters
      rigidBodyDesc.positions = topology.atoms.map(\.position)
      let rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
      rigidBodies.append(rigidBody)
    }
    
    housing.rigidBody = rigidBodies.removeFirst()
    rods[0].rigidBody = rigidBodies.removeFirst()
    rods[1].rigidBody = rigidBodies.removeFirst()
    rods[2].rigidBody = rigidBodies.removeFirst()
    rods[3].rigidBody = rigidBodies.removeFirst()
    driveWall.rigidBody = rigidBodies.removeFirst()
  }
}

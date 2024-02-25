// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // Demonstrate transmission of a clock signal in one of the 2 available
  // directions. It should demonstrate the sequence of clock phases expected in
  // the full ALU. Measure how short the switching time can be.
  
  var housing = Housing()
  var rods: [Rod] = []
  for xIndex in 0..<2 {
    for yIndex in 0..<2 {
      var descriptor = RodDescriptor()
      descriptor.xIndex = xIndex
      descriptor.yIndex = yIndex
      let rod = Rod(descriptor: descriptor)
      rods.append(rod)
    }
  }
  let driveWall = DriveWall()
  
  // ===== START: testing each part's relaxed structure =====
  
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = housing.topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = housing.topology.bonds
  var parameters = try! MM4Parameters(descriptor: paramsDesc)
  for i in parameters.atoms.indices {
    if parameters.atoms.ringTypes[i] == 5 {
      
    } else if parameters.atoms.centerTypes[i] == .quaternary {
      parameters.atoms.masses[i] = 0
    }
  }
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = housing.topology.atoms.map(\.position)
  forceField.minimize()
  for i in housing.topology.atoms.indices {
    let position = forceField.positions[i]
    housing.topology.atoms[i].position = position
  }
  
  // ===== END: testing each part's relaxed structure =====
  
  var output: [Entity] = []
  output += housing.topology.atoms
  for rod in rods {
    output += rod.topology.atoms
  }
  output += driveWall.topology.atoms
  
  return output
}

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
  // - Take at least one screenshot to document this experiment.
  
  // MARK: - Compile Parts
  
  let housing = Housing()
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
  
  // MARK: - Other Setup
  
  var topologies: [Topology] = []
  topologies.append(housing.topology)
  for rod in rods {
    topologies.append(rod.topology)
  }
  topologies.append(driveWall.topology)
  
  var systemAtoms: [Entity] = []
  for topology in topologies {
    systemAtoms += topology.atoms
  }
  
  let minimizer = createMinimizer(topologies: topologies)
  minimizer.positions = systemAtoms.map(\.position)
  minimizer.minimize()
  for i in systemAtoms.indices {
    let position = minimizer.positions[i]
    systemAtoms[i].position = position
  }
  
  return systemAtoms
}

func createMinimizer(topologies: [Topology]) -> MM4ForceField {
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

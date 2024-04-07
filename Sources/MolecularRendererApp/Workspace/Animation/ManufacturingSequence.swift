//
//  ManufacturingSequence.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/5/24.
//

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics

struct ManufacturingSequence {
  var manufacturingPartAtomSequences: [[Entity]]
  var manufacturingPartTimeSpans: [Int] = [1200, 600, 600, 1500]
  
  var frameCount: Int {
    manufacturingPartTimeSpans.reduce(0, +)
  }
  
  init(driveSystem: DriveSystem) {
    var system = driveSystem
    system.connectingRod.rigidBody.centerOfMass = SIMD3(0, 20, 0)
    system.flywheel.rigidBody.centerOfMass = SIMD3(-10, 12, 0)
    system.housing.rigidBody.centerOfMass = SIMD3(0, 0, 0)
    system.piston.rigidBody.centerOfMass = SIMD3(10, 12, 0)
    
    func alignZ(rigidBody: inout MM4RigidBody) {
      var minZ: Float = .greatestFiniteMagnitude
      for position in rigidBody.positions {
        minZ = min(minZ, position.z)
      }
      let deltaZ: Float = 0.690 - minZ
      rigidBody.centerOfMass.z += Double(deltaZ)
    }
    alignZ(rigidBody: &system.connectingRod.rigidBody)
    alignZ(rigidBody: &system.flywheel.rigidBody)
    alignZ(rigidBody: &system.housing.rigidBody)
    alignZ(rigidBody: &system.piston.rigidBody)
    
    // Collect up all the atoms, in the order they will be assembled.
    manufacturingPartAtomSequences = []
    manufacturingPartAtomSequences.append(
      Self.createManufacturingSequence(
        rigidBody: system.connectingRod.rigidBody))
    manufacturingPartAtomSequences.append(
      Self.createManufacturingSequence(
        rigidBody: system.flywheel.rigidBody))
    manufacturingPartAtomSequences.append(
      Self.createManufacturingSequence(
        rigidBody: system.piston.rigidBody))
    manufacturingPartAtomSequences.append(
      Self.createManufacturingSequence(
        rigidBody: system.housing.rigidBody))
  }
  
  static func createManufacturingSequence(
    rigidBody: MM4RigidBody
  ) -> [Entity] {
    // Create the atoms.
    var atoms: [Entity] = []
    for atomID in rigidBody.parameters.atoms.indices {
      let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
      let position = rigidBody.positions[atomID]
      let storage = SIMD4(position, Float(atomicNumber))
      atoms.append(Entity(storage: storage))
    }
    
    // Identity the hydrogens attached to each center atom.
    var topology = Topology()
    topology.insert(atoms: atoms)
    topology.insert(bonds: rigidBody.parameters.bonds.indices)
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    let halogenAtomicNumbers: [UInt8] = [1, 9, 17, 35, 53]
    
    // Sort the atoms in an order suited for 3D printing.
    typealias KeyValuePair = (key: Int, value: [Entity])
    var keyValuePairs: [KeyValuePair] = []
    for atomID in atoms.indices {
      // Scale the position into a set of bins.
      let atom = atoms[atomID]
      var position = SIMD3<Double>(atom.position)
      position += SIMD3(100, 100, 100)
      position /= 0.400 // voxels are 0.4x0.4x0.4 nm^3
      if any(position .< 0) || any(position .> 2 * 250) {
        fatalError("Position exceeded allowable range, -100 nm to +100 nm.")
      }
      
      // Create a hash for the bin.
      var hash: Int = .zero
      hash += Int(position[0].rounded(.down))
      hash += Int(position[1].rounded(.down)) << 20
      hash += Int(position[2].rounded(.down)) << 40
      
      // Append the atom and its bonded hydrogens/halogens.
      if halogenAtomicNumbers.contains(atom.atomicNumber) {
        // Skip over this atom.
      } else {
        var outputAtomicNumbers: [UInt32] = []
        outputAtomicNumbers.append(UInt32(atomID))
        
        // Iterate over the bonded neighbors.
        for neighborID in atomsToAtomsMap[atomID] {
          let neighbor = topology.atoms[Int(neighborID)]
          guard halogenAtomicNumbers.contains(neighbor.atomicNumber) else {
            continue
          }
          outputAtomicNumbers.append(neighborID)
        }
        
        var value: [Entity] = []
        for atomID in outputAtomicNumbers {
          let atom = topology.atoms[Int(atomID)]
          value.append(atom)
        }
        let pair = (key: hash, value: value)
        keyValuePairs.append(pair)
      }
    }
    keyValuePairs.sort(by: { $0.key <= $1.key })
    
    atoms = []
    for keyValuePair in keyValuePairs {
      atoms += keyValuePair.value
    }
    return atoms
  }
}

extension ManufacturingSequence {
  func findContainingRangeID(frameID: Int) -> Int {
    let partTimeRanges = createPartTimeRanges()
    var containingRangeID: Int?
    for rangeID in partTimeRanges.indices {
      let range = partTimeRanges[rangeID]
      if range.contains(frameID) {
        containingRangeID = rangeID
      }
    }
    guard let containingRangeID else {
      fatalError("Could not find containing range.")
    }
    return containingRangeID
  }
  
  // The time allotted to each part, in frames.
  func createPartTimeRanges() -> [Range<Int>] {
    let partTimeSpans = manufacturingPartTimeSpans
    var partTimeRanges: [Range<Int>] = []
    var partTimeAccumulator: Int = .zero
    for partID in partTimeSpans.indices {
      let timeSpan = partTimeSpans[partID]
      let nextAccumulator = partTimeAccumulator + timeSpan
      let timeRange = partTimeAccumulator..<nextAccumulator
      partTimeAccumulator = nextAccumulator
      partTimeRanges.append(timeRange)
    }
    return partTimeRanges
  }
  
  func atoms(frameID: Int) -> [Entity] {
    let partTimeRanges = createPartTimeRanges()
    let containingRangeID = findContainingRangeID(frameID: frameID)
    let containingRange = partTimeRanges[containingRangeID]
    
    let partAtoms = manufacturingPartAtomSequences[containingRangeID]
    var progressInt = partAtoms.count
    progressInt *= frameID - containingRange.lowerBound
    progressInt /= (containingRange.count - 1)
    let progressFloat = min(1.0, Float(progressInt) / Float(partAtoms.count))
    
    var frame: [Entity] = []
    for partID in 0..<containingRangeID {
      frame += manufacturingPartAtomSequences[partID]
    }
    for atomID in partAtoms.indices {
      let atom = partAtoms[atomID]
      let atomProgress = Float(atomID) / Float(partAtoms.count)
      guard atomProgress < progressFloat else {
        continue
      }
      frame.append(atom)
    }
    
    return frame
  }
}

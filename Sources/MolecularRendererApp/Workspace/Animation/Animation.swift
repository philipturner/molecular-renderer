//
//  Animation.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/5/24.
//

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics

struct Animation: MRAtomProvider {
  // Stored properties.
  var surface: Surface
  var manufacturingPartAtomSequences: [[Entity]]
  var manufacturingPartTimeSpans: [Int] = [1200, 600, 600, 1500]
  
  // Computed properties.
  var atomCount: Int {
    var output: Int = .zero
    output += surface.topology.atoms.count
    for partAtomSequence in manufacturingPartAtomSequences {
      output += partAtomSequence.count
    }
    return output
  }
  var frameCount: Int {
    manufacturingPartTimeSpans.reduce(0, +)
  }
  
  // Object initializer.
  init() {
    surface = Surface()
    
    var system = DriveSystem()
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
    //
    // TODO: Instead of Morton order, use an order suited for 3D printing.
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
    
    // Phases:
    // - Manufacturing
    // - Assembly
    // - Operation
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

extension Animation {
  func atoms(time: MRTime) -> [MRAtom] {
    var frameID = time.absolute.frames
    frameID = min(frameID, frameCount - 1)
    
    // The time allotted to each part, in frames.
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
    
    var containingRange: Range<Int>?
    var containingRangeID: Int?
    for rangeID in partTimeRanges.indices {
      let range = partTimeRanges[rangeID]
      if range.contains(frameID) {
        containingRange = range
        containingRangeID = rangeID
      }
    }
    guard let containingRange,
          let containingRangeID else {
      fatalError("Could not find containing range.")
    }
    
    let partAtoms = manufacturingPartAtomSequences[containingRangeID]
    var progress = partAtoms.count
    progress *= frameID - containingRange.lowerBound
    progress /= (containingRange.count - 1)
    
    var frame: [Entity] = []
    frame += surface.topology.atoms
    for partID in 0..<containingRangeID {
      frame += manufacturingPartAtomSequences[partID]
    }
    for atomID in partAtoms.indices {
      let atom = partAtoms[atomID]
      guard atomID < progress else {
        continue
      }
      frame.append(atom)
    }
    
    return frame.map {
      MRAtom(origin: $0.position, element: $0.atomicNumber)
    }
  }
}

//
//  CBNTripod.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/29/23.
//

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

// Although the name 'CBNTripod' implies it's just the tripod, the data
// structure actually represents the entire scene. This includes the Si(111)
// surface.
//
// This data structure holds objects wrapping the individual components. At the
// end, it stitches them all together into one topology. The data structure
// establishes a practice of creating functions for exporting [Entity], similar
// to the convention from the nanofactory animation. However, there is also an
// alternative way to acquire the final geometry: a Topology.
//
// There should be different functions that change the topology in different
// ways, or export different structures. One might replace the silicons
// attached to the NH groups with hydrogens, so the tripod can be simulated as
// a standalone structure.
struct CBNTripod {
  var cage: CBNTripodCage
  var legs: [CBNTripodLeg] = []
  // TODO: Add the surface.
  
  // Indices of the atoms corresponding to each cage-leg bond.
  var cagePivotIDs: [Int] = []
  var legPivotIDs: [Int] = []
  
  init() {
    self.cage = CBNTripodCage()
    
    let leg = CBNTripodLeg()
    for legID in 0..<3 {
      var output = leg
      let angleDegrees1 = Float(90)
      let angleDegrees2 = Float(legID) / 3 * 360
      let rotation1 = Quaternion<Float>(
        angle: angleDegrees1 * .pi / 180, axis: [0, 1, 0])
      let rotation2 = Quaternion<Float>(
        angle: angleDegrees2 * .pi / 180, axis: [0, 1, 0])
      
      for i in output.topology.atoms.indices {
        var atom = output.topology.atoms[i]
        atom.position = rotation1.act(on: atom.position)
        atom.position += SIMD3(0, -0.62, 0.4)
        atom.position = rotation2.act(on: atom.position)
        output.topology.atoms[i] = atom
      }
      legs.append(output)
    }
    precondition(createAtoms().count == 75)
    
    // Connect the legs to the cage and delete their methyl carbons.
    var carbonylCarbonIDs: [UInt32] = []
    var cageCarbonIDs: [UInt32] = []
    for legID in legs.indices {
      var topology = legs[legID].topology
      let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
      
      var methylCarbonID: Int = -1
      var benzeneCarbonID: Int = -1
      for i in topology.atoms.indices {
        let atom = topology.atoms[i]
        let neighbors = atomsToAtomsMap[i]
        if atom.atomicNumber == 6 && neighbors.count == 1 {
          methylCarbonID = i
          benzeneCarbonID = Int(neighbors.first!)
          break
        }
      }
      precondition(methylCarbonID >= 0)
      precondition(benzeneCarbonID >= 0)
      
      var methylCarbon = topology.atoms[methylCarbonID]
      var benzeneCarbon = topology.atoms[benzeneCarbonID]
      let matches = cage.topology.match(
        [methylCarbon, benzeneCarbon], algorithm: .absoluteRadius(0.020))
      
      // Snap the leg into position on the adamantane cage.
      let cageCarbonID = Int(matches[0].first!)
      let cageCarbon = cage.topology.atoms[cageCarbonID]
      let translation = cageCarbon.position - methylCarbon.position
      for i in topology.atoms.indices {
        var atom = topology.atoms[i]
        atom.position += translation
        topology.atoms[i] = atom
      }
      
      // Update the methyl and benzene carbons with their new positions.
      methylCarbon = topology.atoms[methylCarbonID]
      benzeneCarbon = topology.atoms[benzeneCarbonID]
      
      // Fetch the carbonyl carbon and append the IDs to the list.
      let carbonylCarbonID = Int(matches[1].first!)
      let carbonylCarbon = cage.topology.atoms[carbonylCarbonID]
      carbonylCarbonIDs.append(UInt32(carbonylCarbonID))
      cageCarbonIDs.append(UInt32(cageCarbonID))
      
      // Rotate the leg down and under, so its open orbital aligns with the
      // carbonyl group's sp2 C - sp3 C orbital.
      var orbitalCage = carbonylCarbon.position - cageCarbon.position
      var orbitalLeg = benzeneCarbon.position - methylCarbon.position
      orbitalCage /= (orbitalCage * orbitalCage).sum().squareRoot()
      orbitalLeg /= (orbitalLeg * orbitalLeg).sum().squareRoot()
      
      // ~0.27-0.28° rotation for all 3 legs.
      let rotation = Quaternion<Float>(from: orbitalLeg, to: orbitalCage)
      for i in topology.atoms.indices {
        if i == methylCarbonID {
          continue
        }
        var atom = topology.atoms[i]
        var delta = atom.position - methylCarbon.position
        delta = rotation.act(on: delta)
        atom.position = methylCarbon.position + delta
        topology.atoms[i] = atom
      }
      
      // Replace the benzene carbon with a germanium marker that survives the
      // atom removal.
      topology.atoms[benzeneCarbonID].atomicNumber = 32
      topology.remove(atoms: [UInt32(methylCarbonID)])
      
      var germaniumID: Int = -1
      for i in topology.atoms.indices {
        if topology.atoms[i].atomicNumber == 32 {
          germaniumID = i
          continue
        }
      }
      precondition(germaniumID >= 0)
      topology.atoms[germaniumID].atomicNumber = 6
      
      // Update the leg's topology and initialize its pivot ID.
      legs[legID].topology = topology
      self.legPivotIDs.append(germaniumID)
    }
    
    // Delete the carbonyl groups from the adamantane cage.
    do {
      precondition(carbonylCarbonIDs.count == 3)
      precondition(cageCarbonIDs.count == 3)
      var topology = cage.topology
      let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
      
      // Replace the cage carbons with silicon markers while they are removed.
      // Since the order of the atoms does not change, they still correspond to
      // the same atoms, even after the indices contract.
      var removedAtoms: [UInt32] = []
      for legID in 0..<3 {
        let carbonylCarbonID = Int(carbonylCarbonIDs[legID])
        let cageCarbonID = Int(cageCarbonIDs[legID])
        topology.atoms[cageCarbonID].atomicNumber = 14
        
        let atom = topology.atoms[carbonylCarbonID]
        precondition(atom.atomicNumber == 6)
        
        let neighbors = atomsToAtomsMap[carbonylCarbonID]
        for neighborID in neighbors {
          let neighbor = topology.atoms[Int(neighborID)]
          if neighbor.atomicNumber == 14 {
            continue
          }
          if neighbor.atomicNumber == 6 {
            fatalError("This should never happen.")
          }
          removedAtoms.append(neighborID)
        }
        removedAtoms.append(UInt32(carbonylCarbonID))
      }
      
      // Initialize the cage's pivot IDs.
      topology.remove(atoms: removedAtoms)
      for i in topology.atoms.indices {
        guard topology.atoms[i].atomicNumber == 14 else {
          continue
        }
        topology.atoms[i].atomicNumber = 6
        cagePivotIDs.append(i)
      }
      precondition(cagePivotIDs.count == 3)
      
      // Update the cage's topology.
      cage.topology = topology
    }
    precondition(createAtoms().count == 63)
  }
  
  mutating func rotateTripods() {
    
  }
  
  // Add a function to irreversibly replace the silicon atoms with hydrogen
  // atoms. In practice, you might make a copy of the tripod data structure.
  // Mutate the copy, simulate it, and transfer data back to the original.
  
  func createAtoms() -> [Entity] {
    var output: [Entity] = []
    output += cage.topology.atoms
    for leg in legs {
      output += leg.topology.atoms
    }
    return output
  }
}

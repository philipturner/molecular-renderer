//
//  Tripod.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/3/24.
//

import Foundation
import HDL
import MM4
import Numerics

// A tooltip with an adamantane cage, formed by stripping a tripod of its legs
// and feedstock.
struct Tooltip {
  var topology = Topology()
  
  // All of the ghost atoms should be kept positionally constrained.
  var ghostAtomIDs: [UInt32] {
    var output: [UInt32] = []
    for atomID in topology.atoms.indices {
      if atomID >= 22 {
        output.append(UInt32(atomID))
      }
    }
    return output
  }
  
  init(tripodAtoms: [Entity]) {
    topology.insert(atoms: tripodAtoms)
    topology.atoms.removeSubrange(22...)
    
    createBonds()
    createGhostCarbons()
    passivateGhostCarbons()
  }
  
  // Forms a (potentially incorrect) bonding topology for the entire structure,
  // but the important part (leg attachment point) will always be correct.
  mutating func createBonds() {
    // 1.2 covalent bond lengths produces a completely correct topology for:
    // - 'TripodCache.germaniumSet.radical'
    // - 'TripodCache.tinSet.hydrogen'
    let matches = topology.match(
      topology.atoms, algorithm: .covalentBondLength(1.2))
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      for j in matches[i] where i < j {
        let bond = SIMD2(UInt32(i), UInt32(j))
        insertedBonds.append(bond)
      }
    }
    topology.insert(bonds: insertedBonds)
  }
  
  mutating func createGhostCarbons() {
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp3)
    
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      let orbitalSet = orbitals[atomID]
      guard orbitalSet.count > 0 else {
        continue
      }
      guard atom.atomicNumber == 6, atom.position.y < 0.4600 else {
        continue
      }
      
      guard orbitalSet.count == 1 else {
        fatalError("Orbital set had unexpected size.")
      }
      let orbital = orbitalSet.first!
      
      // Source: MM3 Tinker Parameters
      // atom 1 - atom 3 (sp3 carbon - carbonyl carbon)
      let ccBondLength: Float = 1.5090 / 10
      let carbonPosition = atom.position + orbital * ccBondLength
      let carbon = Entity(position: carbonPosition, type: .atom(.carbon))
      
      let carbonID = topology.atoms.count + insertedAtoms.count
      insertedAtoms.append(carbon)
      insertedBonds.append(SIMD2(UInt32(atomID), UInt32(carbonID)))
      
      // Rotate the CHO group to match the orientation of the leg.
      var oxygenOrbital = SIMD3<Float>(0, -1, 0)
      let rotation1 = Quaternion(angle: 7 * Float.pi / 180, axis: [0, 1, 0])
      let rotation2 = Quaternion(angle: -70 * .pi / 180, axis: orbital)
      oxygenOrbital = rotation1.act(on: oxygenOrbital)
      oxygenOrbital = rotation2.act(on: oxygenOrbital)
      
      // Source: MM3 Tinker Parameters
      // atom 3 - atom 7 (carbonyl carbon - carbonyl oxygen)
      let coBondLength: Float = 1.2080 / 10
      let oxygenPosition = carbon.position + oxygenOrbital * coBondLength
      let oxygen = Entity(position: oxygenPosition, type: .atom(.oxygen))
      
      let oxygenID = topology.atoms.count + insertedAtoms.count
      insertedAtoms.append(oxygen)
      insertedBonds.append(SIMD2(UInt32(carbonID), UInt32(oxygenID)))
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  mutating func passivateGhostCarbons() {
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp2)
    
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in ghostAtomIDs {
      let atom = topology.atoms[Int(atomID)]
      guard atom.atomicNumber == 6 else {
        continue
      }
      
      for orbital in orbitals[Int(atomID)] {
        // Source: MM3 Tinker Parameters
        // atom 3 - atom 5 (carbonyl carbon - carbonyl hydrogen)
        let chBondLength: Float = 1.1180 / 10
        let position = atom.position + orbital * chBondLength
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        insertedAtoms.append(hydrogen)
        insertedBonds.append(SIMD2(UInt32(atomID), UInt32(hydrogenID)))
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Returns a snapshot of the internal state, for rendering.
  func createFrame() -> [Entity] {
    return topology.atoms
  }
}

// Store the tripods in their own reference frame. "Project" the tripods to
// render and/or query forces from the simulator. Then, undo the mapping to
// convert forces or position changes to the local reference frame.
struct Tripod {
  var tooltip: Tooltip
  var legAtoms: [Entity] = []
  var feedstockAtoms: [Entity] = []
  
  init(atoms: [Entity]) {
    tooltip = Tooltip(tripodAtoms: atoms)
    legAtoms = Array(atoms[22..<70])
    feedstockAtoms = Array(atoms[70...])
  }
  
  // Inverts the tripod's Y coordinates, then projects it upwards by the
  // specified amount (in nm).
  mutating func project(distance: Float) {
    func project(atom: inout Entity) {
      atom.position.y = -atom.position.y
      atom.position.y += distance
    }
    
    for atomID in tooltip.topology.atoms.indices {
      project(atom: &tooltip.topology.atoms[atomID])
    }
    for atomID in legAtoms.indices {
      project(atom: &legAtoms[atomID])
    }
  }
  
  // Returns all the atoms currently contained in the object.
  func createFrame() -> [Entity] {
    // Exclude the hydrogens from the tooltip.
    var output: [Entity] = []
    for atomID in tooltip.topology.atoms.indices {
      let atom = tooltip.topology.atoms[atomID]
      if tooltip.ghostAtomIDs.contains(UInt32(atomID)) {
        continue
      }
      output.append(atom)
    }
    output.append(contentsOf: legAtoms)
    output.append(contentsOf: feedstockAtoms)
    return output
  }
}

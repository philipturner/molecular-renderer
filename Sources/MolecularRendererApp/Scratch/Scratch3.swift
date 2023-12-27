//
//  Scratch3.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/27/23.
//

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics

struct Reconstruction {
  var topology: Topology = Topology()
  var initialTypes: [MM4CenterType] = []
  
  // These lists must always be sorted.
  var hydrogensToAtomsMap: [[UInt32]] = []
  var atomsToHydrogensMap: [[UInt32]] = []
  
  enum CollisionState {
    case keep
    case bond
    case oneHydrogen(Int)
  }
  
  // There should be some method for the user to specify how 2-way and 3-way
  // collisions were resolved.
  // ->
  // Perhaps a piece of data post-application that can be used to nudge atoms
  // into a position of lower energy. Or the nudges are applied during apply().
  // ->
  // If any structures have 4-way collisions, we'll need to automatically patch
  // them. Otherwise, just crash because they don't fit into the rule system.
  
  mutating func prepare() {
    removePathologialAtoms()
    createBulkAtomBonds()
    createHydrogenSites()
  }
  
  mutating func apply() {
    createHydrogenBonds()
  }
  
  // Arrange the surface into something you could reasonably expect a molecular
  // mechanics simulator to accept.
  //
  // This can be called in a separate Reconstruction object that the one that
  // did the original bond rearrangement. For example, the first Reconstruction
  // object might rearrange some bonds before the object is transformed into a
  // self-referential shell structure. After merging carbons on both ends, you
  // still need to adjust the atoms before a simulator will accept them.
  mutating func minimize() {
    // Nudge the atoms into a lower-energy position. This may happen as a
    // post-processing effect, after the structure is warped.
    // - Make sure the overlap after warping a self-referential structure
    //   deletes hydrogens that may be out-of-line with the lattice (due to
    //   orbitals changing with the reconstructed bonds).
    // - If the shift to something self-referential creates cyclic graphs of
    //   lines of bonds, that may be an issue. You must resolve this ambiguity.
  }
  
  // Resolving three-way collisions requires something additional - a
  // specification of which hydrogen will survive.
  mutating func updateCollisions(_ states: [CollisionState]) {
    var insertedBonds: [SIMD2<UInt32>] = []
    
  outer:
    for i in states.indices {
      precondition(
        i >= 0 && i < hydrogensToAtomsMap.count,
        "Hydrogen index out of bounds.")
      
      switch states[i] {
      case .keep:
        continue outer
      case .bond:
        break
      case .oneHydrogen(_):
        fatalError("This update is not reported yet.")
      }
      
      let atomList = hydrogensToAtomsMap[Int(i)]
      precondition(atomList.count == 2, "Not a two-way collision.")
      hydrogensToAtomsMap[Int(i)] = []
      
      let bond = SIMD2(atomList[0], atomList[1])
      insertedBonds.append(bond)
      
      for j in atomList {
        precondition(
          j >= 0 && j < atomsToHydrogensMap.count,
          "Atom index is out of bounds.")
        var previous = atomsToHydrogensMap[Int(j)]
        precondition(previous.count > 0, "Hydrogen map already empty.")
        
        var matchIndex = -1
        for k in previous.indices {
          if previous[k] == UInt32(i) {
            matchIndex = k
            break
          }
        }
        precondition(matchIndex != -1, "Could not find a match.")
        previous.remove(at: matchIndex)
        atomsToHydrogensMap[Int(j)] = previous
      }
    }
    topology.insert(bonds: insertedBonds)
  }
}

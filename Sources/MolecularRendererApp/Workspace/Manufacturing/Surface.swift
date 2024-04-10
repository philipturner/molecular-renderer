//
//  Surface.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/10/24.
//

import Foundation
import HDL
import MM4
import Numerics

// A partially-hydrogenated partially-chlorinated silicon surface.
//
// Accepts a programmable 'Lattice<Cubic>' and generates the passivated surface
// from it. The current form of the code relies on a built-in
// 'createLattice()', but we'll likely need to make it more flexible in the
// future.
struct Surface {
  var topology: Topology
  
  init() {
    let lattice = Self.createLattice()
    topology = Self.createTopology(lattice: lattice)
    align()
    passivate()
  }
  
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 40 * (h + k + l) }
      Material { .elemental(.silicon) }
      
      Volume {
        Origin { 20 * (h + k + l) }
        Convex {
          Origin { 0 * (h + k + l) }
          Plane { h + k + l }
        }
        Convex {
          Origin { -1.75 * (h + k + l) }
          Plane { -(h + k + l) }
        }
        
        Convex {
          Origin { 5 * (-h + 2 * k - l) }
          Plane { -h + 2 * k - l }
        }
        Convex {
          Origin { 10 * (h - l) }
          Plane { h - l }
        }
        Convex {
          Origin { -5 * (-h + 2 * k - l) }
          Plane { -(-h + 2 * k - l) }
        }
        Convex {
          Origin { -10 * (h - l) }
          Plane { -(h - l) }
        }
        Replace { .empty }
      }
    }
  }
  
  static func createTopology(lattice: Lattice<Cubic>) -> Topology {
    var topology = Topology()
    topology.insert(atoms: lattice.atoms)
    return topology
  }
  
  mutating func align() {
    // Rotate into the correct basis.
    var basisVector1 = SIMD3<Float>(1, 1, 1)
    var basisVector2 = SIMD3<Float>(1, 0, -1)
    var basisVector3 = SIMD3<Float>(1, -2, 1)
    basisVector1 /= (basisVector1 * basisVector1).sum().squareRoot()
    basisVector2 /= (basisVector2 * basisVector2).sum().squareRoot()
    basisVector3 /= (basisVector3 * basisVector3).sum().squareRoot()
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      var position = atom.position
      position = SIMD3((basisVector2 * position).sum(),
                       (basisVector1 * position).sum(),
                       (basisVector3 * position).sum())
      atom.position = position
      topology.atoms[atomID] = atom
    }
    
    // Shift so the highest atomic layer of Si atoms has a Y coordinate of 0.
    for atomID in topology.atoms.indices {
      var latticeConstant = Constant(.square) { .elemental(.silicon) }
      latticeConstant *= Float(3).squareRoot()
      
      var atom = topology.atoms[atomID]
      atom.position.y += Float(-20) * latticeConstant
      topology.atoms[atomID] = atom
    }
  }
  
  // Requires that the lattice isn't shifted from its original translation in
  // 'align()'.
  mutating func passivate() {
    // Annotate the bonds between the silicons and passivators,
    // even though a full topology isn't generated for bulk atoms.
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      let silicon = topology.atoms[atomID]
      guard silicon.position.y > -0.001 else {
        continue
      }
      
      // The patent said to use 33-50% concentration.
      let concentration: Float = (0.33 + 0.50) / 2
      
      // Randomly choose the passivator.
      var passivatorElement: Element
      if Float.random(in: 0..<1) < concentration {
        passivatorElement = .hydrogen
      } else {
        // Eventually, we'll need to avoid hydrogen under the sites where
        // tripods will be placed. And/or remove passivators entirely.
        //
        // This could happen in a separate function, which transmutes all
        // chlorines under tripod sites to H and shrinks the bond length. The
        // atoms directly under the leg might be handled specially, being
        // rendered as chlorine during a specific point of an animation.
        passivatorElement = .chlorine
      }
      
      // Compile with a bond length from the literature.
      var bondLength: Float
      switch passivatorElement {
      case .hydrogen:
        // Source: MM4Parameters
        bondLength = 1.483 / 10
      case .chlorine:
        // Source: GFN2-xTB simulation of Cl-passivated adamantasilane
        bondLength = 2.029 / 10
      default:
        fatalError("Unexpected passivator element.")
      }
      
      // Create an entity from the above information.
      let position = silicon.position + bondLength * SIMD3(0, 1, 0)
      let passivator = Entity(
        position: position, type: .atom(passivatorElement))
      let passivatorID = topology.atoms.count + insertedAtoms.count
      
      let bond = SIMD2(UInt32(atomID), UInt32(passivatorID))
      insertedAtoms.append(passivator)
      insertedBonds.append(bond)
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
}

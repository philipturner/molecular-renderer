//
//  SheetPart.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/25/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct SheetPart: GenericPart {
  var rigidBody: MM4RigidBody
  
  init() {
    let lattice = Self.createLattice()
    let topology = Self.createTopology(lattice: lattice)
    rigidBody = Self.createRigidBody(topology: topology)
    
    let bulkAtomIDs = Self.extractBulkAtomIDs(topology: topology)
    minimize(bulkAtomIDs: bulkAtomIDs)
  }
  
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 40 * h + 40 * k + 2 * l }
      Material { .elemental(.carbon) }
      
      // Trim away two opposing corners of the square.
      Volume {
        Convex {
          Origin { 30 * k }
          Plane { -h + k }
        }
        Convex {
          Origin { 30 * h }
          Plane { h - k }
        }
        Replace { .empty }
      }
      
      // Shorten the remaining points.
      Volume {
        Convex {
          Origin { 15 * k }
          Plane { -h - k }
        }
        Convex {
          Origin { 40 * h + 25 * k }
          Plane { h + k }
        }
        Replace { .empty }
      }
      
      // Replace the back side with sulfur.
      Volume {
        Origin { 0.25 * l }
        Plane { -l }
        Replace { .atom(.sulfur) }
      }
      
      // Replace the front side with a series of grooves.
      Volume {
        for diagonalID in -20...20 {
          Concave {
            Origin { Float(diagonalID) * (h - k) }
            Origin { 2 * l }
            
            Convex {
              Origin { -0.25 * l }
              Plane { l }
            }
            Convex {
              Origin { -0.25 * (h - k) }
              Plane { h - k }
            }
            Convex {
              Origin { -0.25 * (-h + k) }
              Plane { -h + k }
            }
          }
        }
        
        Replace { .empty }
      }
    }
  }
  
  static func createTopology(lattice: Lattice<Cubic>) -> Topology {
    // Reconstruct the surface.
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.carbon)
    reconstruction.topology.insert(atoms: lattice.atoms)
    reconstruction.compile()
    var topology = reconstruction.topology
    
    // Fetch the neighbors map.
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    let atomsToBondsMap = topology.map(.atoms, to: .bonds)
    
    // Remove the incorrect bonds and passivators.
    var removedAtoms: [UInt32] = []
    var removedBonds: [UInt32] = []
    for i in topology.atoms.indices {
      let atom = topology.atoms[i]
      guard atom.atomicNumber == 16 else {
        continue
      }
      
      let atomsMap = atomsToAtomsMap[i]
      for j in atomsMap {
        let otherAtom = topology.atoms[Int(j)]
        if otherAtom.atomicNumber == 1 {
          removedAtoms.append(j)
        }
      }
      
      let bondsMap = atomsToBondsMap[i]
      for bondID in bondsMap {
        let bond = topology.bonds[Int(bondID)]
        
        var j: UInt32
        if bond[0] == i {
          j = bond[1]
        } else if bond[1] == i {
          j = bond[0]
        } else {
          fatalError("This should never happen.")
        }
        
        let otherAtom = topology.atoms[Int(j)]
        if otherAtom.atomicNumber == 16 {
          removedBonds.append(bondID)
        }
      }
    }
    topology.remove(bonds: removedBonds)
    topology.remove(atoms: removedAtoms)
    
    return topology
  }
}

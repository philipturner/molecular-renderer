//
//  CLAHousing.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/20/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct CLAHousingDescriptor {
  var rods: [Rod] = []
  var cachePath: String?
}

struct CLAHousing: GenericPart {
  var rigidBody: MM4RigidBody
  
  init(descriptor: CLAHousingDescriptor) {
    let lattice = Self.createLattice(rods: descriptor.rods)
    var topology = Self.createTopology(lattice: lattice)
    topology.bonds = Serialization.deserialize(bonds: Serialization.serialize(bonds: topology.bonds))
    rigidBody = Self.createRigidBody(topology: topology)
    
    if let cachePath = descriptor.cachePath {
      let key = Serialization.serialize(atoms: lattice.atoms)
      let valueAtoms = Serialization.serialize(atoms: topology.atoms)
      let valueBonds = Serialization.serialize(bonds: topology.bonds)
      print(lattice.atoms.count, topology.atoms.count, topology.bonds.count)
      print(key.count, valueAtoms.count, valueBonds.count)
    }
    
    rigidBody.centerOfMass.z -= 18 * 0.3567
  }
  
  static func createLattice(rods: [Rod]) -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 74 * h + 38 * k + 59 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        // Remove a slab of atoms from the front.
        Convex {
          Origin { 58.25 * l }
          Plane { l }
        }
        
        // Remove a slab of atoms from the bottom.
        Convex {
          Origin { 2 * k }
          Plane { -k }
        }
        
        // Remove a chunk in the [-X, -Z] direction.
        Concave {
          Origin { 50 * h }
          Plane { -h }
          
          Origin { 18 * l }
          Plane { -l }
        }
        
        // Remove a chunk in the [+X, +Z] direction.
        Concave {
          Origin { 64.25 * h }
          Plane { h }
          
          Origin { 14 * l }
          Plane { l }
        }
        Replace { .empty }
      }
      
      // Remove chunks that spawned from the carry out.
      Volume {
        // Remove a chunk in the [-X, +Y] direction.
        Concave {
          Origin { 50 * h }
          Plane { -h }
          
          Origin { 34.5 * k }
          Plane { k }
        }
        
        // Remove a chunk in the [+X, +Y] direction.
        Concave {
          Origin { 58 * h }
          Plane { h }
          
          Origin { 34.5 * k }
          Plane { k }
        }
        
        Replace { .empty }
      }
      
      // Remove a layer from the bottom of the entire machine.
      Volume {
        // Remove a chunk in the [+X, -Z] direction.
        Concave {
          Origin { 20 * h }
          Plane { h }
          
          Origin { 6 * k }
          Plane { -k }
          
          Origin { 42 * l }
          Plane { -l }
        }
        
        // Remove a chunk in the [-X, -Z] direction.
        Concave {
          Origin { 12 * h }
          Plane { -h }
          
          Origin { 6 * k }
          Plane { -k }
          
          Origin { 42 * l }
          Plane { -l }
        }
        
        // Remove a chunk in the [+X, +Z] direction.
        Concave {
          Origin { 40 * h }
          Plane { h }
          
          Origin { 6 * k }
          Plane { -k }
          
          Origin { 50 * l }
          Plane { l }
        }
        
        // Remove a chunk in the [-X, +Z] direction.
        Concave {
          Origin { 12 * h }
          Plane { -h }
          
          Origin { 6 * k }
          Plane { -k }
          
          Origin { 50 * l }
          Plane { l }
        }
        
        Replace { .empty }
      }
      
      // Remove a set of chunks, which appear like steps.
      // - Only trimming the first step.
      Volume {
        // Y=6 to Y=12
        Concave {
          Concave {
            Origin { 26 * h }
            Plane { h }
          }
          Concave {
            Origin { 50 * h }
            Plane { -h }
          }
          
          Origin { 12 * k }
          Plane { -k }
          
          Origin { 36 * l }
          Plane { -l }
        }
        
        Replace { .empty }
      }
      
      // Remove chunks for the holes.
      Volume {
        for rod in rods {
          var volume = rod.createExcludedVolume(padding: 0)
          volume.minimum.z += 18
          volume.maximum.z += 18
          
          Concave {
            Concave {
              Origin { volume.minimum * (h + k + l) }
              Plane { h }
              Plane { k }
              Plane { l }
            }
            Concave {
              Origin { volume.maximum * (h + k + l) }
              Plane { -h }
              Plane { -k }
              Plane { -l }
            }
          }
        }
        Replace { .empty }
      }
    }
  }
}

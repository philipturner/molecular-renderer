//
//  RobotFinger.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/11/24.
//

import HDL
import MM4

struct RobotGripper {
  // Idea: both a topology and rigid body exist. The topology can map custom
  // element types onto the rigid body's simulated positions for rendering.
  var topology = Topology()
  var rigidBody: MM4RigidBody?
  
  init() {
    compilationPass0()
    compilationPass1()
    compilationPass2()
    compilationPass3()
    compilationPass4()
  }
  
  mutating func compilationPass0() {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 8 * h + 10 * h2k + 3 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        // Cut the tip of the finger.
        Convex {
          Origin { 0.5 * l }
          Plane { -l }
        }
        Convex {
          Origin { 3.5 * h }
          Plane { -h }
        }
        Convex {
          Origin { 6 * h + h2k }
          Plane { -k - 2 * h }
        }
        Convex {
          Plane { -h2k }
        }
        Convex {
          Origin { 2.25 * l }
          Plane { l }
        }
        Convex {
          Origin { 8 * h2k }
          Plane { h2k }
        }
        
        // Cut away some stuff on the top left.
        Concave {
          Origin { 4 * h + 5.5 * h2k }
          Plane { h2k }
          Plane { -h }
        }
        
        // Cut away some stuff in the middle. Leave a thin sheet that attaches
        // to the centerpiece.
        Concave {
          Origin { 5 * h + 5 * h2k }
          Plane { h }
          Plane { h2k }
          Convex {
            Origin { 1 * h2k }
            Plane { k + 2 * h }
          }
          Convex {
            Origin { 2.5 * h + 0.25 * h2k }
            Plane { k }
            Plane { k + h }
          }
          Convex {
            Origin { 2.5 * h }
            Plane { -h }
          }
        }
        Replace { .empty }
        
        // Trim away part of the graphane-like sheet.
        Concave {
          Origin { 6.5 * h + 7.25 * h2k }
          Plane { h }
          Plane { h2k }
        }
        Replace { .empty }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  mutating func compilationPass1() {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 6 * h + 5 * h2k + 3 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 3 * h }
        // Cut the front and back to be flush with the lattice from pass 0.
        Convex {
          Origin { 0.5 * l }
          Plane { -l }
        }
        Convex {
          Origin { 2.25 * l }
          Plane { l }
        }
        
        // Cut the band part that's a bit thicker than in lattice 0.
        Convex {
          Origin { 1.5 * h }
          Origin { -0.5 * h2k }
          Plane { -k - 2 * h }
          Plane { -k + h }
        }
        Convex {
          Origin { -2.5 * h }
          Plane { -h }
        }
        Convex {
          Origin { 2 * h }
          Plane { h }
        }
        
        Concave {
          Origin { 0 * h + 3.0 * h2k }
          Plane { h }
          Plane { k / 2 + h }
        }
        
        Replace { .empty }
        
        Convex {
          Origin { 4 * h2k }
          Plane { h2k }
          Replace { .atom(.silicon) }
        }
      }
    }
    var atoms = lattice.atoms
    
    // Offset the lattice by an integer number of 'Hexagonal' unit vectors,
    // aligning perfectly with the previous lattice.
    var h = SIMD3<Float>(1, 0, 0)
    var k = SIMD3<Float>(-1.0 / 2, Float(3.0 / 4).squareRoot(), 0)
    var l = SIMD3<Float>(0, 0, 1)
    h *= Constant(.hexagon) { .elemental(.carbon) }
    k *= Constant(.hexagon) { .elemental(.carbon) }
    l *= Constant(.prism) { .elemental(.carbon) }
    
    for i in atoms.indices {
      let h2k = h + 2 * k
      atoms[i].position += 0 * h + 8 * h2k
    }
    
    topology.insert(atoms: atoms)
  }
  
  mutating func compilationPass2() {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 2 * h + 6 * h2k + 4 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Plane { -k }
        
        Convex {
          Origin { 0.5 * l }
          Plane { -l }
        }
        Convex {
          Origin { 2.25 * l }
          Plane { l }
        }
        
        Replace { .empty }
      }
    }
    var atoms = lattice.atoms
    
    var h = SIMD3<Float>(1, 0, 0)
    var k = SIMD3<Float>(-1.0 / 2, Float(3.0 / 4).squareRoot(), 0)
    var l = SIMD3<Float>(0, 0, 1)
    h *= Constant(.hexagon) { .elemental(.carbon) }
    k *= Constant(.hexagon) { .elemental(.carbon) }
    l *= Constant(.prism) { .elemental(.carbon) }
    
    for i in atoms.indices {
      let h2k = h + 2 * k
      atoms[i].position += 8 * h + 7 * h2k
    }
    topology.insert(atoms: atoms)
  }
  
  mutating func compilationPass3() {
    let radius = Element.carbon.covalentRadius * 2
    let matches = topology.match(
      topology.atoms, algorithm: .absoluteRadius(1.5 * radius))
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      for j in matches[i] where i < j {
        insertedBonds.append(SIMD2(UInt32(i), UInt32(j)))
      }
    }
    topology.insert(bonds: insertedBonds)
    
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    
    var removedAtoms: [UInt32] = []
    for i in topology.atoms.indices {
      if atomsToAtomsMap[i].count <= 1 {
        removedAtoms.append(UInt32(i))
      }
    }
    topology.remove(atoms: removedAtoms)
    
    let orbitals = topology.nonbondingOrbitals()
    let chBondLength = Element.carbon.covalentRadius +
    Element.hydrogen.covalentRadius
    
    var insertedAtoms: [Entity] = []
    insertedBonds = []
    for i in topology.atoms.indices {
      let carbon = topology.atoms[i]
      for orbital in orbitals[i] {
        let position = carbon.position + orbital * chBondLength
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        let bond = SIMD2(UInt32(i), UInt32(hydrogenID))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(bond)
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
    topology.sort()
  }
  
  mutating func compilationPass4() {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.bonds = topology.bonds
    paramsDesc.atomicNumbers = topology.atoms.map {
      if $0.atomicNumber == 1 { return 1 }
      else { return 6 }
    }
    var parameters = try! MM4Parameters(descriptor: paramsDesc)
    for i in topology.atoms.indices {
      if topology.atoms[i].atomicNumber == 14 {
        parameters.atoms.masses[i] = 0
      }
    }
    
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = parameters
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    forceField.positions = topology.atoms.map(\.position)
    forceField.minimize()
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = forceField.positions
    rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
}

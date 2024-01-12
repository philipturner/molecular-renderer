//
//  RobotBuildSite.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/11/24.
//

import HDL
import QuaternionModule

// The scene that the robot fingers act on. It is different in each of the two
// videos. Two parts:
// - 'RobotBuildPlate', the anchored floor/plate.
// - 'RobotMolecule', the piece the robot picks up.

// struct RobotBuiltSite
// - struct RobotBuildPlate
// - struct RobotBuildMolecule

struct RobotBuildPlate {
  var topology = Topology()
  
  init(video: RobotVideo) {
    if video == .version1 {
      compilationPass0(boundsH: 18)
    } else if video == .version2 {
      compilationPass0(boundsH: 36)
      compilationPass1()
      compilationPass2()
    }
  }
  
  mutating func compilationPass0(boundsH: Float) {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { boundsH * h + 9 * h2k + 4 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Convex {
          Origin { 0.5 * l }
          Plane { -l }
        }
        Convex {
          Origin { 1.25 * l }
          Plane { l }
        }
        Convex {
          Origin { 0.5 * h }
          Plane { -h }
        }
        
        Replace { .empty }
      }
    }
    var atoms = lattice.atoms
    
    for i in atoms.indices {
      var position = atoms[i].position
      position = SIMD3(position.x, position.z, position.y)
      atoms[i].position = position
    }
    topology.insert(atoms: atoms)
  }
  
  mutating func compilationPass1() {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 16 * h + 16 * h2k + 3 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 8 * h + 8 * h2k }
        
        var directions: [SIMD3<Float>] = []
        directions.append(h + k / 2)
        directions.append(h / 2 + k)
        directions.append(-h / 2 + k / 2)
        directions.append(contentsOf: directions.map(-))
        
        var offsets: [SIMD3<Float>] = []
        offsets.append(0.75 * (h + k))
        offsets.append(0.75 * (h + k))
        offsets.append(.zero)
        offsets.append(.zero)
        offsets.append(.zero)
        offsets.append(0.75 * (h + k))
        
        for (direction, offset) in zip(directions, offsets) {
          Convex {
            Origin { 6 * direction + offset }
            Plane { direction }
          }
        }
        Concave {
          for (direction, offset) in zip(directions, offsets) {
            Convex {
              Origin { 4 * direction + offset }
              Plane { -direction }
            }
          }
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
      atoms[i].position.y = -atoms[i].position.y
      atoms[i].position += 20 * h + 13 * h2k + 1.5 * l
    }
    
    for i in atoms.indices {
      var position = atoms[i].position
      position = SIMD3(position.x, position.z, position.y)
      atoms[i].position = position
    }
    topology.insert(atoms: atoms)
  }
  
  mutating func compilationPass2() {
    let matches = topology.match(topology.atoms)
    
    var bonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      for j in matches[i] where i < j {
        bonds.append(SIMD2(UInt32(i), j))
      }
    }
    topology.insert(bonds: bonds)
    
    let orbitals = topology.nonbondingOrbitals()
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    let chBondLength = Element.carbon.covalentRadius +
    Element.hydrogen.covalentRadius
    
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      let carbon = topology.atoms[i]
      func addOrbital(_ orbital: SIMD3<Float>) {
        let position = carbon.position + orbital * chBondLength
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        let hydrogenID = UInt32(topology.atoms.count + insertedAtoms.count)
        insertedAtoms.append(hydrogen)
        insertedBonds.append(SIMD2(UInt32(i), hydrogenID))
      }
      for orbital in orbitals[i] {
        addOrbital(orbital)
      }
      
      // Patch the primary carbons so we keep the same atom count as in the
      // video.
      let neighbors = atomsToAtomsMap[i]
      if neighbors.count == 1 {
        // Generate an orbital for the 1 bond that exists.
        let neighbor = topology.atoms[Int(neighbors.first!)]
        var neighborOrbital = neighbor.position - carbon.position
        neighborOrbital /= (
          neighborOrbital * neighborOrbital).sum().squareRoot()
        
        // Generate an axis to rotate 109.5° around.
        let randomVector = SIMD3<Float>(-1, 0, 0)
        var axis = cross_platform_cross(neighborOrbital, randomVector)
        axis /= (axis * axis).sum().squareRoot()
        let rotation1 = Quaternion(angle: 109.47 * .pi / 180, axis: axis)
        let orbital1 = rotation1.act(on: neighborOrbital)
        addOrbital(orbital1)
        
        // Rotate 120° around the neighbor orbital for the other hydrogens.
        let rotation2 = Quaternion(angle: 2 * .pi / 3, axis: neighborOrbital)
        let orbital2 = rotation2.act(on: orbital1)
        let orbital3 = rotation2.act(on: orbital2)
        addOrbital(orbital2)
        addOrbital(orbital3)
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
    topology.sort()
  }
}

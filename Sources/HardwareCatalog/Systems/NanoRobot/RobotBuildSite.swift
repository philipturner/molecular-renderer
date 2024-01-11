//
//  RobotBuildSite.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/11/24.
//

import HDL

// The scene that the robot fingers act on. It is different in each of the two
// videos. Two parts:
// - 'RobotBuildPlate', the anchored floor/plate.
// - 'RobotMolecule', the piece the robot picks up.

// struct RobotBuiltSite
// - struct RobotBuildPlate
// - struct RobotBuildMolecule

struct RobotBuildPlate {
  var topology = Topology()
  // eventually an MM4RigidBody?
  
  init(video: RobotVideo) {
    if video == .version1 {
      compilationPass0(boundsH: 18)
    } else if video == .version2 {
      compilationPass0(boundsH: 36)
      compilationPass1()
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
    for atomID in topology.atoms.indices {
//      for
    }
    
    // Break the ground with MM4ForceField by minimizing the colliding hydrogens
    // in this structure (compilation pass 3).
  }
}

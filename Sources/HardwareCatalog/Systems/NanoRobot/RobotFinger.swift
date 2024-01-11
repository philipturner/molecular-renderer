//
//  RobotFinger.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/11/24.
//

import HDL

struct RobotFinger {
  var topology = Topology()
  
  init() {
    // Split the part into several different lattices, each of which can be
    // designed in isolation. This decreases the amount of confounding variables
    // when trying to avoid collisions between far-away placed crystal planes.
    //
    // Neat side-effect of splitting into separte compilaton passes: you can
    // deactivate the atoms of any one part, to visualize just that part. Helps
    // when you'd otherwise have a lot of unrelated geometry visually crowding
    // the scene.
    compilationPass0()
    compilationPass1()
    compilationPass2()
    
    // Some attachment points are marked with fluorine for identification later
    // in the compilation. Meanwhile, passivate the finger with hydrogen and
    // move on to compiling other sections of the geometry.
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
        
        // Cut away some stuff in the middle. We'll attach a sheet of graphane
        // to create band that attaches to the centerpiece.
        func middlePlanes() {
          Origin { 5 * h + 5 * h2k }
          Plane { h }
          Plane { h2k }
          Convex {
            Origin { 1 * h2k }
            Plane { k + 2 * h }
          }
        }
        Volume {
          Concave {
            middlePlanes()
            Replace { .atom(.fluorine) }
          }
        }
        Concave {
          middlePlanes()
          Convex {
            Origin { 2.5 * h + 0.25 * h2k }
            Plane { k }
            Plane { k + h }
          }
        }
        Replace { .empty }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  mutating func compilationPass1() {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 4 * h + 4 * h2k + 3 * l }
      Material { .elemental(.carbon) }
      
      Volume {
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
          Origin { 0.5 * h }
          Plane { -h }
        }
        Convex {
          Origin { 2.5 * h }
          Plane { h }
        }
        Convex {
          Origin { 3 * h2k }
          Plane { h2k }
        }
        
        Replace { .empty }
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
      atoms[i].position += 3 * h + 8 * h2k
    }
    
    topology.insert(atoms: atoms)
  }
  
  mutating func compilationPass2() {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 6 * h + 1 * h2k + 6 * l }
      Material { .elemental(.carbon) }
    }
    var atoms = lattice.atoms
    
    var h = SIMD3<Float>(1, 0, 0)
    var k = SIMD3<Float>(-1.0 / 2, Float(3.0 / 4).squareRoot(), 0)
    var l = SIMD3<Float>(0, 0, 1)
    h *= Constant(.hexagon) { .elemental(.carbon) }
    k *= Constant(.hexagon) { .elemental(.carbon) }
    l *= Constant(.prism) { .elemental(.carbon) }
    
    for i in atoms.indices {
      // We need to flip the atoms upside down to align correctly with the
      // hexagon orientation from the video.
      atoms[i].position.y = -atoms[i].position.y
      
      let h2k = h + 2 * k
      atoms[i].position -= 1.5 * l
      atoms[i].position += -2 * h + 4 * h2k
      
      // Offset by the same amount as the atoms from pass 1.
      atoms[i].position += 3 * h + 8 * h2k
    }
    
    topology.insert(atoms: atoms)
  }
}

struct GraphaneBand {
  var toppology = Topology()
  
  init() {
    // Defer the creation of graphane bands until the very last step. In the
    // meantime, create all of the other geometry and mark attachment points.
    // Reproduce the structure from the first video to start off, as you can
    // determine the atom count with certainty. Then, move on to the more
    // complex 3-finger system.
  }
}

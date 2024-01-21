// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 4 * h + 4 * k + 4 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Origin { 2 * h + 2 * k + 2 * l }
      Origin { 0.25 * (h + k - l) }
      
      // Remove the front plane.
      Convex {
        Origin { 0.25 * (h + k + l) }
        Plane { h + k + l }
      }
      
      func triangleCut(sign: Float) {
        Convex {
          Origin { 0.25 * sign * (h - k - l) }
          Plane { sign * (h - k / 2 - l / 2) }
        }
        Convex {
          Origin { 0.25 * sign * (k - l - h) }
          Plane { sign * (k - l / 2 - h / 2) }
        }
        Convex {
          Origin { 0.25 * sign * (l - h - k) }
          Plane { sign * (l - h / 2 - k / 2) }
        }
      }
      
      // Remove three sides forming a triangle.
      triangleCut(sign: +1)
      
      // Remove their opposites.
      triangleCut(sign: -1)
      
      // Remove the back plane.
      Convex {
        Origin { -0.25 * (h + k + l) }
        Plane { -(h + k + l) }
      }
      
      Replace { .empty }
      
      Volume {
        Origin { 0.20 * (h + k + l) }
        Plane { h + k + l }
        Replace { .atom(.silicon) }
      }
    }
  }
  
  // Center the adamantane at (0, 0, 0).
  var atoms = lattice.atoms
  var accumulator: SIMD3<Float> = .zero
  for atom in atoms {
    accumulator += atom.position
  }
  accumulator /= Float(atoms.count)
  
  // Rotate the adamantane and make the three bridge carbons flush.
  let rotation1 = Quaternion<Float>(angle: .pi / 4, axis: [0, 1, 0])
  let rotation2 = Quaternion<Float>(angle: 35.26 * .pi / 180, axis: [0, 0, 1])
  var maxX: Float = -.greatestFiniteMagnitude
  for i in atoms.indices {
    var position = atoms[i].position
    position -= accumulator
    position = rotation1.act(on: position)
    position = rotation2.act(on: position)
    atoms[i].position = position
    maxX = max(maxX, position.x)
  }
  for i in atoms.indices {
    atoms[i].position.x -= maxX
    atoms[i].position.x -= Element.carbon.covalentRadius
  }
  
  // Create the second half.
  atoms += atoms.map {
    var copy = $0
    copy.position.x = -copy.position.x
    if copy.atomicNumber == 14 {
      copy.atomicNumber = 82
    }
    return copy
  }
  
  for i in atoms.indices {
    if atoms[i].atomicNumber == 14 {
      atoms[i].atomicNumber = 50
    }
  }
  
  return atoms
}

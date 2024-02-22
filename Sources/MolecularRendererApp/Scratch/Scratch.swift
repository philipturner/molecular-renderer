// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  // Create a flywheel-driven drive system structure.
  let backBoardLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 400 * h + 100 * h2k + 6 * l }
    Material { .checkerboard(.silicon, .carbon) }
    
    Volume {
      Origin { 90 * h + 50 * h2k }
      
      // Rightmost two triangles.
      Concave {
        Origin { 4 * h2k }
        Origin { 3 * h }
        Plane { h2k }
        Plane { h - k }
        
        Origin { 70 * h }
        Plane { -k - 2 * h }
      }
      Concave {
        Origin { -4 * h2k }
        Origin { 3 * h }
        Plane { -h2k }
        Plane { k + 2 * h }
        
        Origin { 70 * h }
        Plane { k - h }
      }
      
      // Leftmost two triangles.
      Concave {
        Origin { -80 * h }
        Origin { 4 * h2k }
        Origin { 3 * h }
        Plane { h2k }
        Plane { h - k }
        
        Origin { 70 * h }
        Plane { -k - 2 * h }
      }
      Concave {
        Origin { -80 * h }
        Origin { -4 * h2k }
        Origin { 3 * h }
        Plane { -h2k }
        Plane { k + 2 * h }
        
        Origin { 70 * h }
        Plane { k - h }
      }
      
      Replace { .empty }
    }
  }
  
  var minPosition = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
  var maxPosition = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
  for atom in backBoardLattice.atoms {
    minPosition.replace(with: atom.position, where: atom.position .< minPosition)
    maxPosition.replace(with: atom.position, where: atom.position .> maxPosition)
  }
  print(maxPosition - minPosition)
  print(backBoardLattice.atoms.count)
  
  return backBoardLattice.atoms
}

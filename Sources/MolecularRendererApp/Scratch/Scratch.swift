// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  // Create a flywheel-driven drive system structure.
  //
  // General process structure:
  // - 1) Rough sketch
  // - 2) Break into smaller parts that are manufacturable
  // - 3) Add hydrogens and simulate
  let germaniumCarbide = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 2 * h + 100 * h2k + 2 * l }
    Material { .checkerboard(.germanium, .carbon) }
  }
  var atoms = germaniumCarbide.atoms
  
  var minPosition: SIMD3<Float> = .init(repeating: .greatestFiniteMagnitude)
  var maxPosition: SIMD3<Float> = .init(repeating: -.greatestFiniteMagnitude)
  for atom in atoms {
    let position = atom.position
    minPosition.replace(with: position, where: position .< minPosition)
    maxPosition.replace(with: position, where: position .> maxPosition)
  }
  
  print(maxPosition - minPosition)
  
  var output: [Entity] = []
  for spokeID in 0..<3 {
    let angle = Float(spokeID) * 2 * Float.pi / 3
    let rotation = Quaternion(angle: angle, axis: [0, 0, 1])
    for var atom in atoms {
      atom.position.x -= 0.28
      atom.position = rotation.act(on: atom.position)
      output.append(atom)
    }
  }
  
  let diamond = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 2 * h + 100 * h2k + 2 * l }
    Material { .checkerboard(.germanium, .carbon) }
  }
  atoms = diamond.atoms
  
  
  return output
}

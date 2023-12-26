// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MolecularRenderer
import Numerics

// TODO: Save this first example of (100) reconstruction to a GitHub gist

func render100Reconstruction() -> [MRAtom] {
  var lattices: [Lattice<Cubic>] = []
  lattices.append(latticeBasic100())
  lattices.append(latticeAdvanced100())
  let topologies = lattices.map(reconstruct100(_:))
  
  var diamondoid = latticeDiamondoid()
  diamondoid.transform { $0.origin.y -= 3 }
  
  var output: [MRAtom] = []
  output += diamondoid.atoms
  output += topologies[0].atoms.map(MRAtom.init)
  output += topologies[1].atoms.map(MRAtom.init).map {
    var copy = $0
    copy.origin.x += 3
    return copy
  }
  return output
}

func latticeDiamondoid() -> Diamondoid {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 6 * (h + k + l) }
    Material { .elemental(.carbon) }
  }
  var atoms = lattice.atoms.map(MRAtom.init).map(Optional.init)
  
outer:
  for i in atoms.indices {
    let selfAtom = atoms[i]!
    for j in atoms.indices where i != j {
      if let otherAtom = atoms[j] {
        let delta = selfAtom.origin - otherAtom.origin
        let distance = (delta * delta).sum().squareRoot()
        if distance < 0.154 * 1.2 {
          continue outer
        }
      }
    }
    atoms[i] = nil
  }
  
  return Diamondoid(atoms: atoms.compactMap { $0 })
}

func latticeBasic100() -> Lattice<Cubic> {
  Lattice<Cubic> { h, k, l in
    Bounds { 6 * (h + k + l) }
    Material { .elemental(.carbon) }
  }
}

// Find a good example of geometry that typically requires lonsdaleite,
// and includes (110)/(111) planes.
func latticeAdvanced100() -> Lattice<Cubic> {
  Lattice<Cubic> { h, k, l in
    Bounds { 6 * (h + k + l) }
    Material { .elemental(.carbon) }
    
    Volume {
      Convex {
        Origin { 2 * (h + k + l) }
        
        var directionPairs: [(SIMD3<Float>, SIMD3<Float>)] = []
        directionPairs.append((-h, -k))
        directionPairs.append((-h, -l))
        directionPairs.append((-k, -l))
        for pair in directionPairs {
          Concave {
            Plane { pair.0 }
            Plane { pair.1 }
          }
        }
      }
      
      Convex {
        Origin { 5 * (h + k + l) }
        Plane { k + l }
        
        Origin { -3 * h }
        Origin { 1.5 * (h - k + l) }
        Valley(h + k + l) { k }
      }
      
      Convex {
        Origin { 5 * k + 3 * l }
        Valley(k + l) { k }
      }
      
      Concave {
        Convex {
          Origin { 5 * k + 2.5 * l }
          Valley(k + l) { k }
        }
        Convex {
          Origin { 3 * h }
          Plane { -h  }
        }
      }
      
      Convex {
        Origin { 5 * h + 1 * k + 5 * l }
        Plane { h - k + l }
      }
      
      Replace { .empty }
    }
  }
}

func reconstruct100(_ lattice: Lattice<Cubic>) -> Topology {
  var topology = Topology()
  topology.insert(atoms: lattice.atoms)
  return topology
}

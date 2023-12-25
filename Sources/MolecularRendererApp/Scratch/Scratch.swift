// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MolecularRenderer
import Numerics

func renderScratch() -> [MRAtom] {
  let lattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 4 * h + 3 * h2k + 3 * l }
    Material { .elemental(.carbon) }
  }
  let atoms = lattice.atoms.map(MRAtom.init)
  let diamondoid = Diamondoid(atoms: atoms)
  
  // MARK: - Lattice -> Diamondoid Pipeline
  
  var output: [MRAtom] = []
  output += renderAtomOrder(atoms).map {
    var copy = $0
    copy.origin += SIMD3(0, 0, 0)
    return copy
  }
  output += renderAtomOrder(diamondoid.atoms).map {
    var copy = $0
    copy.origin += SIMD3(10, 0, 0)
    return copy
  }
  
  let diamondoidBonds = diamondoid.bonds.map {
    SIMD2<UInt32>(truncatingIfNeeded: $0)
  }
  output += renderBonds(diamondoid.atoms, diamondoidBonds).map {
    var copy = $0
    copy.origin += SIMD3(20, 0, 0)
    return copy
  }
  
  // MARK: - Topology.sort()
  
  var topology = Topology()
  topology.insert(atoms: lattice.atoms)
  
  let latticeAtomIndices: [UInt32] = lattice.atoms.indices.map { UInt32($0) }
  topology.remove(atoms: latticeAtomIndices)
  
  let diamondoidEntities = diamondoid.atoms.map {
    var storage = SIMD4<Float>($0.origin, 0)
    storage.w = Float($0.element)
    return Entity(storage: storage)
  }
  topology.insert(atoms: diamondoidEntities.reversed())
  topology.sort()
  let atomsFromReversed = topology.atoms
  topology.remove(atoms: topology.atoms.indices.map(UInt32.init))
  topology.insert(atoms: diamondoidEntities.shuffled())
  
  output += renderAtomOrder(topology.atoms.map(MRAtom.init)).map {
    var copy = $0
    copy.origin += SIMD3(0, 0, 10)
    return copy
  }
  
  let originalAtoms = topology.atoms
  let reordering = topology.sort()
  
  var reorderedAtoms = originalAtoms
  var reorderedMap = [Int](repeating: -1, count: originalAtoms.count)
  for originalID in reordering.indices {
    let reorderedID = reordering[originalID]
    let reorderedID64 = Int(truncatingIfNeeded: reorderedID)
    reorderedAtoms[reorderedID64] = originalAtoms[originalID]
    reorderedMap[reorderedID64] = originalID
  }
  precondition(reorderedAtoms == topology.atoms)
  precondition(reorderedAtoms == atomsFromReversed)
  precondition(topology.atoms == atomsFromReversed)
  
  output += renderAtomOrder(reorderedAtoms.map(MRAtom.init)).map {
    var copy = $0
    copy.origin += SIMD3(10, 0, 10)
    return copy
  }
  
  topology.remove(atoms: topology.atoms.indices.map(UInt32.init))
  topology.insert(atoms: diamondoidEntities)
  topology.insert(bonds: diamondoid.bonds.map {
    SIMD2<UInt32>(truncatingIfNeeded: $0)
  })
  topology.sort()
  
  output += renderBonds(topology.atoms.map(MRAtom.init), topology.bonds).map {
    var copy = $0
    copy.origin += SIMD3(20, 0, 10)
    return copy
  }

  return output
}

func renderScratch2() -> [[MRAtom]] {
  let lattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 4 * h + 3 * h2k + 3 * l }
    Material { .elemental(.carbon) }
  }
  let atoms = lattice.atoms.map(MRAtom.init)
  let diamondoid = Diamondoid(atoms: atoms)
  let diamondoidEntities = diamondoid.atoms.map {
    var storage = SIMD4<Float>($0.origin, 0)
    storage.w = Float($0.element)
    return Entity(storage: storage)
  }
  
  var topology = Topology()
  topology.insert(atoms: diamondoidEntities)
  topology.insert(bonds: diamondoid.bonds.map {
    SIMD2<UInt32>(truncatingIfNeeded: $0)
  })
  topology.sort()
  return renderAtomOrder2(topology.atoms.map(MRAtom.init))
}

/*
 // It may be helpful to have a utility function for
 // debugging bonds. For example, explode the crystal lattice and place marker
 // atoms on an interpolated line between actual atoms. Presence of malformed
 // bonds will be extremely obvious.
 //
 // - 1) Visualizer for Morton order and bond topology in GitHub gist.
 //   - 1.1) Test against Lattice -> Diamondoid reordering.
 //   - 1.2) Test against Topology.sort().
 */

func renderAtomOrder(_ atoms: [MRAtom]) -> [MRAtom] {
  var output: [MRAtom] = []
  var previous: MRAtom?
  
  for atom in atoms {
    var gold = atom
    gold.origin *= 5
    gold.element = 79
    
    if let previous {
      let start = previous.origin
      let delta = gold.origin - previous.origin
      let deltaLength = (delta * delta).sum().squareRoot()
      let deltaNormalized = delta / deltaLength
      
      var distance: Float = 0.1
      while distance < deltaLength {
        let origin = start + deltaNormalized * distance
        let helium = MRAtom(origin: origin, element: 2)
        output.append(helium)
        distance += 0.1
      }
    }
    output.append(gold)
    previous = gold
  }
  return output
}

func renderAtomOrder2(_ atoms: [MRAtom]) -> [[MRAtom]] {
  var output: [MRAtom] = []
  var frameCount = 0
  var previous: MRAtom?
  
  for atom in atoms {
    var gold = atom
    gold.origin *= 5
    gold.element = 79
    
    if let previous {
      let start = previous.origin
      let delta = gold.origin - previous.origin
      let deltaLength = (delta * delta).sum().squareRoot()
      let deltaNormalized = delta / deltaLength
      
      var distance: Float = 0.1
      while distance < deltaLength {
        let origin = start + deltaNormalized * distance
        let helium = MRAtom(origin: origin, element: 2)
        output.append(helium)
        distance += 0.1
      }
    }
    output.append(gold)
    frameCount += 1
    previous = gold
  }
  
  var frames: [[MRAtom]] = []
  for i in 0..<frameCount {
    let frameEnd = max(1, i * output.count / frameCount)
    frames.append(Array(output[..<frameEnd]))
  }
  return frames
}

func renderBonds(_ atoms: [MRAtom], _ bonds: [SIMD2<UInt32>]) -> [MRAtom] {
  var output: [MRAtom] = []
  for atom in atoms {
    var gold = atom
    gold.origin *= 5
    gold.element = 79
    output.append(gold)
  }
  for bond in bonds {
    let bond64 = SIMD2<Int>(truncatingIfNeeded: bond)
    let start = 5 * atoms[bond64.x].origin
    let end = 5 * atoms[bond64.y].origin
    
    let delta = end - start
    let deltaLength = (delta * delta).sum().squareRoot()
    let deltaNormalized = delta / deltaLength
    
    var distance: Float = 0.1
    while distance < deltaLength {
      let origin = start + deltaNormalized * distance
      let helium = MRAtom(origin: origin, element: 2)
      output.append(helium)
      distance += 0.1
    }
  }
  return output
}

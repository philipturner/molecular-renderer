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
  
  // TODO: - Clean up the code for debugging Morton reordering after the
  // debugging is finished. Turn it into a good test case.
  
  // To create an HDL test case, print the expected values for atoms and bonds
  // into a Swift array literal.
  var topology = Topology()
  topology.insert(atoms: lattice.atoms)
  
  let latticeAtomIndices: [UInt32] = lattice.atoms.indices.map { UInt32($0) }
  let diamondoidBondIndices: [UInt32] = diamondoidBonds.indices.map {
    UInt32($0)
  }
  topology.remove(atoms: latticeAtomIndices)
  precondition(topology.atoms.count == 0)
  precondition(topology.bonds.count == 0)
  
  let diamondoidEntities = diamondoid.atoms.map {
    var storage = SIMD4<Float>($0.origin, 0)
    storage.w = Float($0.element)
    return Entity(storage: storage)
  }
  topology.insert(atoms: diamondoidEntities.shuffled())
  output += renderAtomOrder(topology.atoms.map(MRAtom.init)).map {
    var copy = $0
    copy.origin += SIMD3(0, 0, 10)
    return copy
  }
  
  let grid = TopologyGrid(atoms: topology.atoms, cellWidth: 1)
  let reorderStart = cross_platform_media_time()
  let reordering = grid.mortonReordering()
  let reorderEnd = cross_platform_media_time()
  print("time to sort", Int((reorderEnd - reorderStart) / 1e-6))
  
  var reorderedAtoms = topology.atoms
  var reorderedMap = [Int](repeating: -1, count: topology.atoms.count)
  for originalID in reordering.indices {
    let reorderedID = reordering[originalID]
    let reorderedID64 = Int(truncatingIfNeeded: reorderedID)
    reorderedAtoms[reorderedID64] = topology.atoms[originalID]
    reorderedMap[reorderedID64] = originalID
  }
  
  // Generate reordering based on depth-first traversal of octree.
  var octreeReordering: [Int] = []
  
  // Bounds are roughly -0.5 to 1.5.
//  print(topology.atoms.map { $0.position }.reduce(into: SIMD3<Float>(5, 5, 5)) {
//    $0.replace(with: $1, where: $1 .< $0)
//  })
  let start = cross_platform_media_time()
  func traverseOctree(atomIDs: [Int], origin: SIMD3<Float>, levelSize: Float, depth: Int) {
//    let prefix = String(repeating: "-", count: depth)
//    print(prefix, origin, atomIDs.count)
    if levelSize <= 1 / 32 || atomIDs.count <= 1 {
      octreeReordering += atomIDs
      return
    }
    
    // TODO: Speed up octree traversal after you know it makes correct outputs.
    // Profile the octree against the existing sorter for large crystals.
    var dictionary: [SIMD3<Int32>: [Int]] = [:]
    
    for atomID in atomIDs {
      var index: SIMD3<Int32> = .init(repeating: 1)
      let atomPosition = topology.atoms[atomID].position + SIMD3(1, 1, 1)
      index.replace(with: .init(repeating: -1), where: atomPosition .< origin)
      
      var list: [Int] = dictionary[index] ?? []
      list.append(atomID)
      dictionary[index] = list
    }
//    precondition(
//      dictionary.keys.count >= 1 && dictionary.keys.count <= 8)
    
    let sortedKeys = dictionary.keys.sorted {
      if $0.z != $1.z {
        return $0.z < $1.z
      }
      if $0.y != $1.y {
        return $0.y < $1.y
      }
      if $0.x != $1.x {
        return $0.x < $1.x
      }
      return true
    }
    for key in sortedKeys {
      let newOrigin = origin + SIMD3<Float>(key) * levelSize / 2
      let values = dictionary[key]!
      traverseOctree(atomIDs: values, origin: newOrigin, levelSize: levelSize / 2, depth: depth + 1)
    }
  }
  traverseOctree(atomIDs: topology.atoms.indices.map { $0 }, origin: .zero, levelSize: 4, depth: 1)
  let end = cross_platform_media_time()
  print("time to traverse", Int((end - start) / 1e-6))
  
  for (lhs, rhs) in zip(reorderedMap, octreeReordering) {
    print(Int(lhs) - Int(rhs))
  }
  
  output += renderAtomOrder(reorderedAtoms.map(MRAtom.init)).map {
    var copy = $0
    copy.origin += SIMD3(10, 0, 10)
    return copy
  }
  
  // TODO: Shuffle the indices for atoms in a random order, then re-map the
  // bonds accordingly.
  
  // TODO: In a separate test case, invert the positions of the atoms and ensure
  // the bonds are reordered properly.
  topology.insert(atoms: diamondoidEntities)
  topology.insert(bonds: diamondoidBonds)
  precondition(topology.atoms.count > 0)
  precondition(topology.bonds.count > 0)
  
  topology.remove(bonds: diamondoidBondIndices)
  precondition(topology.bonds.count == 0)
  topology.insert(bonds: diamondoidBonds)
  precondition(topology.bonds.count > 0)
  
  return output
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

// MARK: - Debugging Raw Source Code

struct TopologyGrid {
  let atoms: [Entity]
  var cells: [[UInt32]] = []
  var atomsToCellsMap: [SIMD2<UInt32>] = []
  
  // Origin and dimensions are in discrete multiples of cell width.
  var cellWidth: Float
  var origin: SIMD3<Int32>
  var dimensions: SIMD3<Int32>
  
  init(atoms: [Entity], cellWidth: Float = 1.0) {
    self.atoms = atoms
    self.cellWidth = cellWidth
    
    if atoms.count == 0 {
      origin = .zero
      dimensions = .zero
    } else {
      var minimum: SIMD3<Float> = .init(repeating: .greatestFiniteMagnitude)
      var maximum: SIMD3<Float> = .init(repeating: -.greatestFiniteMagnitude)
      for atom in atoms {
        let position = atom.position
        minimum.replace(with: position, where: position .< minimum)
        maximum.replace(with: position, where: position .> maximum)
      }
      minimum /= cellWidth
      maximum /= cellWidth
      minimum.round(.down)
      maximum.round(.up)
      origin = SIMD3<Int32>(minimum)
      dimensions = SIMD3<Int32>(maximum - minimum)
    }
    print(origin, dimensions)
    
    // Use checking arithmetic to ensure the multiplication doesn't overflow.
    let cellCount = Int32(dimensions[0] * dimensions[1] * dimensions[2])
    cells = Array(repeating: [], count: Int(cellCount))
    atomsToCellsMap = Array(repeating: .zero, count: atoms.count)
    
    for atomID in atoms.indices {
      let atom = atoms[atomID]
      precondition(atom.storage.w != 0, "Empty entities are not permitted.")
      precondition(
        atom.storage.w == Float(Int8(atom.storage.w)),
        "Atomic number must be between 1 and 127.")
      
      var position = atom.position
      position /= cellWidth
      position.round(.down)
      let originDelta = SIMD3<Int32>(position) &- self.origin
      let cellID = self.createCellID(originDelta: originDelta)
      
      let mappedAtomID = cells[cellID].count
      cells[cellID].append(UInt32(truncatingIfNeeded: atomID))
      
      let location = SIMD2<Int>(cellID, mappedAtomID)
      atomsToCellsMap[atomID] = SIMD2(truncatingIfNeeded: location)
    }
  }
  
  // The input is the position relative to the grid's origin.
  @inline(__always)
  func createCellID(originDelta: SIMD3<Int32>) -> Int {
    var coords = originDelta
    coords.replace(with: SIMD3.zero, where: coords .< 0)
    coords.replace(with: dimensions &- 1, where: coords .>= dimensions)
    
    let x = coords.x
    let y = coords.y &* dimensions[0]
    let z = coords.z &* dimensions[0] &* dimensions[1]
    return Int(x &+ y &+ z)
  }
}

// MARK: - Morton Reordering

// Source: https://stackoverflow.com/a/18528775
@inline(__always)
private func morton_interleave(_ input: Int32) -> UInt64 {
  var x = UInt64(truncatingIfNeeded: input & 0x1fffff)
  x = (x | x &<< 32) & 0x1f00000000ffff
  x = (x | x &<< 16) & 0x1f0000ff0000ff
  x = (x | x &<< 8) & 0x100f00f00f00f00f
  x = (x | x &<< 4) & 0x10c30c30c30c30c3
  x = (x | x &<< 2) & 0x1249249249249249
  return x
}

// Source: https://stackoverflow.com/a/28358035
@inline(__always)
private func morton_deinterleave(_ input: UInt64) -> Int32 {
  var x = input & 0x9249249249249249
  x = (x | (x &>> 2))  & 0x30c30c30c30c30c3
  x = (x | (x &>> 4))  & 0xf00f00f00f00f00f
  x = (x | (x &>> 8))  & 0x00ff0000ff0000ff
  x = (x | (x &>> 16)) & 0xffff00000000ffff
  x = (x | (x &>> 32)) & 0x00000000ffffffff
  return Int32(truncatingIfNeeded: x)
}

// The inputs are 21-bit, unsigned, normalized integers.
@inline(__always)
private func morton_interleave(_ input: SIMD3<Int32>) -> UInt64 {
  let signed = SIMD3<Int32>(truncatingIfNeeded: input)
  let x = morton_interleave(signed.x) << 0
  let y = morton_interleave(signed.y) << 1
  let z = morton_interleave(signed.z) << 2
  return x | y | z
}

extension TopologyGrid {
  func mortonReordering() -> [UInt32] {
    var cellList: [SIMD2<UInt64>] = []
    for z in 0..<dimensions.z {
      for y in 0..<dimensions.y {
        for x in 0..<dimensions.x {
          let originDelta = SIMD3(x, y, z)
          let mortonCode = morton_interleave(originDelta)
          let cellID = createCellID(originDelta: originDelta)
          let cellID64 = UInt64(truncatingIfNeeded: cellID)
          cellList.append(SIMD2(cellID64, mortonCode))
        }
      }
    }
    cellList.sort { $0.y < $1.y }
    
    var output = [UInt32](repeating: .max, count: atoms.count)
    var mortonListSize: Int = 0
    
    var atomList: [SIMD2<UInt64>] = []
    for element in cellList {
      let cellID = Int(truncatingIfNeeded: element[0])
      
//      do {
//        let cell = cells[cellID]
//        for index in cell {
//          output[mortonListSize] = index
//          mortonListSize += 1
//        }
//        continue
//      }
      
      for atomID in cells[cellID] {
        let atom = atoms[Int(atomID)]
        let scaledPosition = atom.position / cellWidth
        let floorPosition = scaledPosition.rounded(.down)
        let originDelta = SIMD3<Int32>(floorPosition) &- self.origin
        guard createCellID(originDelta: originDelta) == cellID else {
          fatalError("Atom was not in the correct cell.")
        }
        
        let remainder = (scaledPosition - floorPosition) * Float(1 << 21)
        var remainderInt = SIMD3<Int32>(remainder)
        let maxValue = SIMD3<Int32>(repeating: (1 << 21 - 1))
        remainderInt.replace(with: 0, where: remainder .< 0)
        remainderInt.replace(with: maxValue, where: remainderInt .> maxValue)
        let mortonCode = morton_interleave(remainderInt)
        let atomID64 = UInt64(truncatingIfNeeded: atomID)
        atomList.append(SIMD2(atomID64, mortonCode))
      }
      atomList.sort { $0.y < $1.y }
      
      for element in atomList {
        let atomID = Int(truncatingIfNeeded: element[0])
        let mortonMapping = UInt32(truncatingIfNeeded: mortonListSize)
        output[atomID] = mortonMapping
        mortonListSize += 1
      }
      atomList.removeAll(keepingCapacity: true)
    }
    
    precondition(
      mortonListSize == atoms.count, "Morton reordered list was invalid.")
    if output.contains(.max) {
      fatalError("Morton reordered list was invalid.")
    }
    return output
  }
}


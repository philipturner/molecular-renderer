//
//  AtomGrid.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/24/23.
//

import Foundation

struct AtomGrid {
  // Tolerance for floating-point error when comparing atom positions.
  static let epsilon: Float = 0.001
  
  // Each atom stores the position in the first three lanes, and the atom type
  // in the fourth. -1 corresponds to "sigma bond". When exporting, delete all
  // atoms whose mask slot is zero.
  struct Atom {
    var data: SIMD4<Float>
    var position: SIMD3<Float> { unsafeBitCast(data, to: SIMD3<Float>.self) }
    var type: Float {
      get { data.w }
      set { data.w = newValue }
    }
  }
  
  // When appending an atom to a cell, add (1 << atoms.count) to the bitmask.
  // Measure the array count before, not after, adding the new atom.
  struct Cell {
    var mask: UInt64
    var atoms: [Atom]?
    
    mutating func append(_ element: Atom, merging: Bool = false) {
      if atoms == nil {
        atoms = []
      }
      if merging {
        var matchMask: SIMD64<Int8> = .init(repeating: -1)
        for i in 0..<atoms.unsafelyUnwrapped.count {
          let delta = atoms.unsafelyUnwrapped[i].position - element.position
          let distance = (delta * delta).sum()
          let index = Int8(truncatingIfNeeded: i)
          matchMask[i] = (distance < epsilon) ? index : 0
        }
        
        let match = matchMask.max()
        if match > -1 {
          let index = Int(truncatingIfNeeded: match)
          let other = atoms.unsafelyUnwrapped[index]
          let selectMask: UInt64 = 1 << index
          
          if self.mask & selectMask == 0 || other.type < element.type {
            atoms?[index].type = element.type
          }
          self.mask |= selectMask
          return
        }
      }
      mask |= 1 << atoms.unsafelyUnwrapped.count
      atoms?.append(element)
    }
  }
  
  var cellWidth: Float
  var dimensions: SIMD3<Int32>
  var origin: SIMD3<Float>
  var cells: [Cell]
  
  func address(coords: SIMD3<Int32>) -> Int {
    var output = coords.z * dimensions.y * dimensions.x
    output &+= coords.y * dimensions.x
    output &+= coords.x
    return Int(truncatingIfNeeded: output)
  }
  
  // Incremental migration path: swap out the backend of Lattice and Solid with
  // a grid in lattice-space, with cell width 1. Then, change to use 0.357.
  init(
    cellWidth: Float,
    dimensions: SIMD3<Int32>,
    origin: SIMD3<Float> = .zero
  ) {
    self.cellWidth = cellWidth
    self.dimensions = dimensions
    self.origin = origin
    self.cells = []
    
    for _ in 0..<dimensions.z {
      for _ in 0..<dimensions.y {
        for _ in 0..<dimensions.x {
          cells.append(Cell(mask: 0, atoms: nil))
        }
      }
    }
  }
  
  // Merging appends are more expensive, as they check for and remove
  // duplicated atoms. When merging multiple grids, consider setting 'merging'
  // to 'false' when adding atoms from the first grid.
  mutating func append(contentsOf other: [Atom], merging: Bool = false) {
    for atom in other {
      let offset = atom.position - origin
      var scaledOffset = offset / cellWidth
      if any(scaledOffset .< 0 - Self.epsilon) ||
          any(scaledOffset .> SIMD3<Float>(dimensions) + Self.epsilon) {
        fatalError("Atom was outside of grid bounds.")
      }
      
      var coords: SIMD3<Int32> = .init(scaledOffset.rounded(.down))
      coords.clamp(lowerBound: .init(repeating: 0), upperBound: dimensions &- 1)
      cells[address(coords: coords)].append(atom, merging: merging)
    }
    
    // Always check that the number of atoms per cell never exceeds 64.
    for cell in cells where (cell.atoms?.count ?? 0) > 64 {
      fatalError("Cell had more than 64 atoms.")
    }
  }
}

// TODO: Add a function for extracting all atoms from the grid in the order
// they appear.
// TODO: Add a function that returns a map, of how to reorder atoms into
// Morton order. This will map the atom positions and bonds to a new location.
extension AtomGrid {
  
}

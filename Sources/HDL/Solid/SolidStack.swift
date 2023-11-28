//
//  SolidStack.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/22/23.
//

import Foundation

// This code will eventually be deleted. However, it is temporarily preserved
// as a useful reference for things like Morton reordering.

#if false

/// Rounds an integer up to the nearest power of 2.
fileprivate func roundUpToPowerOf2(_ input: Int) -> Int {
  1 << (Int.bitWidth - max(0, input - 1).leadingZeroBitCount)
}

/// Rounds an integer down to the nearest power of 2.
fileprivate func roundDownToPowerOf2(_ input: Int) -> Int {
  1 << (Int.bitWidth - 1 - input.leadingZeroBitCount)
}

// Each atom stores the position in the first three lanes, and the atom type
// in the fourth. -1 corresponds to "sigma bond". When exporting, delete all
// atoms whose mask slot is zero.
struct Atom {
  var data: SIMD4<Float>
  var position: SIMD3<Float> { unsafeBitCast(data, to: SIMD3<Float>.self) }
  var atomicNumber: Float {
    get { data.w }
    set { data.w = newValue }
  }
}

struct Grid {
  // Tolerance for floating-point error or error in lattice constants when
  // comparing atom positions.
  // TODO: Override the nominal lonsdaleite lattice constants so they align
  // perfectly with diamond (111) surfaces, using 0.357 nm for diamond.
  static let epsilon: Float = 0.005
  
  // When appending an atom to a cell, add (1 << atoms.count) to the bitmask.
  // Measure the array count before, not after, adding the new atom.
  struct Cell {
    var mask: UInt64
    var atoms: [Atom]?
    
    func match(_ atom: Atom) -> Int32 {
      var match: Int32 = -1
      withUnsafeTemporaryAllocation(of: SIMD64<Int8>.self, capacity: 1) {
        let matchMemory = UnsafeMutablePointer<Int8>(
          OpaquePointer($0.baseAddress)).unsafelyUnwrapped
        for i in 0..<atoms.unsafelyUnwrapped.count {
          let delta = atoms.unsafelyUnwrapped[i].position - atom.position
          let distance = (delta * delta).sum()
          let index = Int8(truncatingIfNeeded: i)
          matchMemory[i] = (distance < epsilon) ? index : 0
        }
        
        let matchMask = $0.baseAddress.unsafelyUnwrapped
        match = Int32(truncatingIfNeeded: matchMask.pointee.max())
      }
      return match
    }
    
    mutating func append(_ atom: Atom) {
      if atoms == nil {
        atoms = []
      }
      mask |= 1 << atoms.unsafelyUnwrapped.count
      atoms?.append(atom)
    }
    
    mutating func merge(_ atom: Atom, match: Int32) {
      let index = Int(truncatingIfNeeded: match)
      let other = atoms.unsafelyUnwrapped[index]
      let selectMask: UInt64 = 1 << index
      
      if self.mask & selectMask == 0 ||
          other.atomicNumber < atom.atomicNumber {
        atoms?[index].atomicNumber = atom.atomicNumber
      }
      self.mask |= selectMask
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
  outer:
    for atom in other {
      let offset = atom.position - origin
      var scaledOffset = offset / cellWidth
      if any(scaledOffset .< 0 - Self.epsilon) ||
          any(scaledOffset .> SIMD3<Float>(dimensions) + Self.epsilon) {
        fatalError("Atom was outside of grid bounds.")
      }
      
      var coords: SIMD3<Int32> = .init(scaledOffset.rounded(.down))
      coords.clamp(lowerBound: SIMD3.zero, upperBound: dimensions &- 1)
      if merging {
        let delta = scaledOffset - SIMD3<Float>(coords)
        var starts: SIMD3<Int32> = .init(repeating: -1)
        starts.replace(with: SIMD3.zero, where: delta .>= 0.5)
        
        for z in starts.z...starts.z + 1 {
          for y in starts.y...starts.y + 1 {
            for x in starts.x...starts.x + 1 {
              var adjusted = coords &+ SIMD3(x, y, z)
              if all(adjusted .>= 0 .& adjusted .<= dimensions &- 1) {
                let address = self.address(coords: coords)
                let match = cells[address].match(atom)
                if match > -1 {
                  cells[address].merge(atom, match: match)
                  continue outer
                }
              }
            }
          }
        }
      }
      
      let address = self.address(coords: coords)
      cells[address].append(atom)
    }
    
    // Always check that the number of atoms per cell never exceeds 64.
    for cell in cells where (cell.atoms?.count ?? 0) > 64 {
      fatalError("Cell had more than 64 atoms.")
    }
  }
}

extension Grid {
  private func cellsPrefixSum() -> [Int32] {
    var output: [Int32] = []
    var sum: Int = 0
    for cell in self.cells {
      output.append(Int32(truncatingIfNeeded: sum))
      sum += cell.atoms?.count ?? 0
    }
    output.append(Int32(truncatingIfNeeded: sum))
    return output
  }
  
  /// WARNING: This is a computed property. Access it sparingly.
  var atoms: [Atom] {
    var output: [Atom] = []
    for cell in self.cells where cell.atoms != nil {
      output.append(contentsOf: cell.atoms.unsafelyUnwrapped)
    }
    return output
  }
  
  /// WARNING: This is a computed property. Access it sparingly.
  ///
  /// Returns a map, of the atoms' new locations when arranged in Morton order.
  /// Usually, a 4/8 grid will be regenerated at 4/24 resolution to maximize
  /// spatial locality.
  var mortonReordering: [Int32] {
    // TODO: Check that results are correct by animating addition of atoms to
    // the scene, one at a time.
    
    // Interleave, sort, then deinterleave.
    //
    // Interleaving algorithm:
    // https://stackoverflow.com/a/18528775
    //
    // Deinterleaving algorithm:
    // https://stackoverflow.com/a/28358035
    
    @inline(__always)
    func morton_interleave(_ input: Int32) -> UInt64 {
      var x = UInt64(truncatingIfNeeded: input & 0x1fffff)
      x = (x | x &<< 32) & 0x1f00000000ffff
      x = (x | x &<< 16) & 0x1f0000ff0000ff
      x = (x | x &<< 8) & 0x100f00f00f00f00f
      x = (x | x &<< 4) & 0x10c30c30c30c30c3
      x = (x | x &<< 2) & 0x1249249249249249
      return x
    }
    
    @inline(__always)
    func morton_deinterleave(_ input: UInt64) -> Int32 {
      var x = input & 0x9249249249249249
      x = (x | (x &>> 2))  & 0x30c30c30c30c30c3
      x = (x | (x &>> 4))  & 0xf00f00f00f00f00f
      x = (x | (x &>> 8))  & 0x00ff0000ff0000ff
      x = (x | (x &>> 16)) & 0xffff00000000ffff
      x = (x | (x &>> 32)) & 0x00000000ffffffff
      return Int32(truncatingIfNeeded: x)
    }
    
    var mortonIndices: [UInt64] = []
    for z in 0..<dimensions.z {
      for y in 0..<dimensions.y {
        for x in 0..<dimensions.x {
          let address = self.address(coords: SIMD3(x, y, z))
          if cells[address].atoms?.count ?? 0 > 0 {
            let morton_x = morton_interleave(x)
            let morton_y = morton_interleave(y)
            let morton_z = morton_interleave(z)
            
            var mortonIndex = morton_x
            mortonIndex |= morton_y << 1
            mortonIndex |= morton_z << 2
            mortonIndices.append(mortonIndex)
          }
        }
      }
    }
    mortonIndices.sort()
    
    let prefixSum = cellsPrefixSum()
    var outputMap: [Int32] = .init(repeating: -1, count: Int(prefixSum.last!))
    var outputMapSize: Int = 0
    for mortonIndex in mortonIndices {
      let x = morton_deinterleave(mortonIndex)
      let y = morton_deinterleave(mortonIndex >> 1)
      let z = morton_deinterleave(mortonIndex >> 2)
      
      let address = self.address(coords: SIMD3(x, y, z))
      guard let atoms = cells[address].atoms else {
        fatalError("Morton indexing happened incorrectly.")
      }
      let inputPrefix = prefixSum[address]
      let outputPrefix = outputMapSize
      outputMapSize += atoms.count
      
      for i in 0..<atoms.count {
        outputMap[outputPrefix + i] = inputPrefix + 1
      }
    }
    return outputMap
  }
  
  /// WARNING: This is a computed property. Access it sparingly.
  ///
  /// If a carbon has more than four bonds, or less than two, this returns
  /// `[-2, -2, -2, -2]`. Therefore, anything checking for invalid bonds should
  /// simply check whether the bond index is less than zero.
  var bonds: [SIMD4<Int32>] {
    // 0.1545855 nm - carbon-carbon bond length, corrected to match diamond
    fatalError("Not implemented.")
  }
  
  /// Returns places where passivation must occur.
  ///
  /// The first 3 slots store the position. The last one stores the atom index
  /// as a floating point number. Passivations corresponding to the same atom
  /// are stored contiguously in memory. The atoms resulting from the
  /// passivations should be run through `.append` in a separate call, which
  /// prevents any atoms from being duplicated. Then, the bond topology should
  /// be regenerated, as the atoms are in a different order.
  ///
  /// If the atom is already passivated at a specific location, that location isn't
  /// returned. Instead, you can check whether a specific atom from the bond
  /// map is hydrogen or a single bond. Duplicated passivations will connect two
  /// carbons to the same hydrogen.
  ///
  /// NOTE: In the DSL, `Passivate` must override previous passivations.
  func passivations(bonds: [SIMD4<Int32>]) -> [SIMD4<Float>] {
    // 0.1545855 nm - carbon-carbon bond length, corrected to match diamond
    fatalError("Not implemented.")
  }
  
  // When adding support for 5-carbon rings (implementing the new MM4):
  //
  // Add a function that returns deltas to atom positions, to fix hydrogens when
  // reconstructing (100) surfaces. This function accepts the bond map as input.
}

// MARK: - Old Code

fileprivate func normalize(_ x: SIMD3<Float>) -> SIMD3<Float> {
  let length = (x * x).sum().squareRoot()
  return length == 0 ? .zero : (x / length)
}

fileprivate func dot(_ x: SIMD3<Float>, _ y: SIMD3<Float>) -> Float {
  return (x * y).sum()
}

struct SolidStack {
  // The atoms in the solid.
  var centers: [SIMD3<Float>: Bool] = [:]
  
  // Absolute origins at each level of the stack.
  var origins: [SIMD3<Float>] = []
  
  // Centers for the object currently being transformed.
  var affineCenters: [SIMD3<Float>: Bool]?
  
  init() {
    self.centers = [:]
    self.origins.append(.zero)
  }
  
  // This should instead store a (possibly duplicated) list of carbon centers,
  // which gets de-duplicated at the end of compilation. Make a common utility
  // shared between the solid stack and regular stack, which handles sorting of
  // atoms into an arbitrarily spaced grid.
  mutating func addCenters(_ centers: [SIMD3<Float>], affine: Bool) {
    if affine {
      precondition(affineCenters != nil)
      for center in centers {
        self.affineCenters![center] = true
      }
    } else {
      for center in centers {
        self.centers[center] = true
      }
    }
  }
  
  mutating func applyOrigin(delta: SIMD3<Float>) {
    origins[origins.count - 1] += delta
  }
  
  mutating func applyReflect(_ vector: SIMD3<Float>) {
    precondition(affineCenters != nil)
    let keys = affineCenters!.keys.map { $0 }
    affineCenters = [:]
    
    let origin = self.origins.last!
    let direction = normalize(vector)
    for key in keys {
      var delta = key - origin
      delta -= 2 * direction * dot(delta, direction)
      
      let original = delta + origin
      let position = (original * 4).rounded(.toNearestOrEven) / 4
      let difference = position - original
      if any((difference .> 0.01) .| (difference .< -0.01)) {
        fatalError("Did not reflect across a (100), (110), or (111) plane.")
      }
      
      affineCenters![origin + delta] = true
    }
  }
  
  mutating func applyRotate(_ vector: SIMD3<Float>) {
    precondition(affineCenters != nil)
    let keys = affineCenters!.keys.map { $0 }
    affineCenters = [:]
    
    let origin = self.origins.last!
    var mask: SIMD3<Int> = .zero
    for i in 0..<3 {
      mask[i] = (vector[i] == 0) ? 0 : 1
    }
    guard mask.wrappedSum() == 1 else {
      // Require that it's rotating around a perfect X, Y, or Z axis for now.
      fatalError("Did not rotate around a perfect X, Y, or Z axis.")
    }
    
    // Just take the sum of all lanes, as we assume only one is nonzero.
    let revolutions = vector.sum()
    let roundedRevolutions = (revolutions * 4).rounded(.toNearestOrEven) / 4
    if abs(roundedRevolutions - revolutions) > 0.01 {
      fatalError("Did not rotate by a multiple of 90 degrees.")
    }
    var rotationCount = Int(rint(roundedRevolutions * 4))
    rotationCount %= 4
    if rotationCount < 0 {
      rotationCount = 4 + rotationCount
    }
    precondition(rotationCount >= 0 && rotationCount < 4)
    
    var rotatedAxis1: Int
    var rotatedAxis2: Int
    switch mask {
    case SIMD3(1, 0, 0):
      rotatedAxis1 = 1
      rotatedAxis2 = 2
    case SIMD3(0, 1, 0):
      rotatedAxis1 = 2
      rotatedAxis2 = 0
    case SIMD3(0, 0, 1):
      rotatedAxis1 = 0
      rotatedAxis2 = 1
    default:
      fatalError("This should never happen.")
    }
    
    for key in keys {
      var delta = key - origin
      for _ in 0..<rotationCount {
        let oldCoord1 = delta[rotatedAxis1]
        let oldCoord2 = delta[rotatedAxis2]
        delta[rotatedAxis1] = -oldCoord2
        delta[rotatedAxis2] = oldCoord1
      }
      
      affineCenters![origin + delta] = true
    }
  }
  
  mutating func applyTranslate(_ vector: SIMD3<Float>) {
    precondition(affineCenters != nil)
    let keys = affineCenters!.keys.map { $0 }
    affineCenters = [:]
    
    for key in keys {
      affineCenters![key + vector] = true
    }
  }
  
  mutating func pushOrigin() {
    origins.append(origins.last!)
  }
  
  mutating func popOrigin() {
    origins.removeLast()
  }
  
  mutating func startAffine() {
    precondition(affineCenters == nil)
    affineCenters = [:]
  }
  
  mutating func endAffine() {
    precondition(affineCenters != nil)
    addCenters(affineCenters!.keys.map { $0 }, affine: false)
    affineCenters = nil
  }
}

#endif

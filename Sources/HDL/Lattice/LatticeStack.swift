//
//  Stack.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/15/23.
//

import Foundation

struct LatticeStackDescriptor {
  // The global descriptor resets as soon as it is used.
  static var global: LatticeStackDescriptor = .init()
  
  // The user may only set each of these one time.
  var bounds: SIMD3<Float>?
  var material: MaterialType?
  var basis: Basis.Type?
}

struct LatticeStack {
  var grid: any LatticeGrid
  var basis: Basis.Type
  
  private static var _global: LatticeStack?
  
  // The getter will never return 'nil', so it is okay to force-unwrap. It is
  // only nullable to the setter can be used to destroy it.
  static var global: LatticeStack? {
    get {
      if let _global {
        return _global
      }
      
      let descriptor = LatticeStackDescriptor.global
      guard let bounds = descriptor.bounds,
            let material = descriptor.material,
            let basis = descriptor.basis else {
        fatalError(
          "Global lattice stack does not exist, and descriptor is incomplete.")
      }
      
      // Reset the global descriptor as soon as it is used.
      LatticeStackDescriptor.global = .init()
      
      // Lazily create a new stack, if all arguments are specified.
      let stack = LatticeStack(bounds: bounds, material: material, basis: basis)
      _global = stack
      return stack
    }
    set {
      _global = newValue
      
      // The destructor for Lattice should remove the reference to the global
      // stack, while the caller may retain it via ARC.
      if newValue == nil {
        // Reset to ensure the descriptor doesn't pollute future ones.
        LatticeStackDescriptor.global = .init()
      }
    }
  }
  
  init(bounds: SIMD3<Float>, material: MaterialType, basis: Basis.Type) {
    self.basis = basis
    if basis == Cubic.self {
      self.grid = CubicGrid(bounds: bounds, material: material)
    } else if basis == Hexagonal.self {
      self.grid = HexagonalGrid(bounds: bounds, material: material)
    } else {
      fatalError("This should never happen.")
    }
  }
}

struct LatticeScope {
  var appliesToParent: Bool
  var usesLogicalAnd: Bool
  
  private var _mask: (any LatticeMask)?
  var mask: (any LatticeMask)? {
    get { _mask }
    set {
      if usesLogicalAnd {
        // Invalidate the cumulative sum.
        accumulatedLogicalOr = nil
      }
      _mask = newValue
    }
  }
  
  var accumulatedLogicalOr: (any LatticeMask)?
}

// MARK: - Old Code


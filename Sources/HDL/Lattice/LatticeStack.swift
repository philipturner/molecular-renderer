//
//  Stack.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/15/23.
//

enum LatticeScopeType {
  case concave
  case convex
  case volume
  
  var appliedToParent: Bool {
    self != .volume
  }
  
  var usesLogicalAnd: Bool {
    self == .concave
  }
}

struct LatticeScope {
  var type: LatticeScopeType
  
  init(type: LatticeScopeType) {
    self.type = type
  }
  
  private var _mask: (any LatticeMask)?
  var mask: (any LatticeMask)? {
    get { _mask }
  }
  
  var accumulatedLogicalOr: (any LatticeMask)?
  
  mutating func combine<T: LatticeMask>(_ other: T) {
    guard let maskCopy = _mask else {
      _mask = other
      return
    }
    guard let maskCopy = maskCopy as? T else {
      fatalError("Combined lattices of different types.")
    }
    
    // Due to some implementation issues, a new Swift array will be allocated
    // every time, instead of just writing to the old array in-place.
    if type.usesLogicalAnd {
      _mask = maskCopy & other
    } else {
      _mask = maskCopy | other
    }
  }
}

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
  var scopes: [LatticeScope]
  
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
    self.scopes = []
  }
  
  func checkScopesValid() {
    guard scopes.count > 0, scopes.first!.type == .volume else {
      fatalError(
        "Plane algebra operations must be encapsulated inside a Volume scope.")
    }
  }
}

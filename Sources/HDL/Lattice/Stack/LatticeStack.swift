//
//  Stack.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/15/23.
//

struct LatticeStackDescriptor {
  // The global descriptor resets as soon as it is used.
  static var global: LatticeStackDescriptor = .init()
  
  // The user may only set each of these one time.
  var bounds: SIMD3<Float>?
  var material: MaterialType?
  var basis: (any _Basis.Type)?
}

struct LatticeStack {
  var grid: any LatticeGrid
  var basis: any _Basis.Type
  var scopes: [LatticeScope] = []
  var origins: [SIMD3<Float>] = []
  
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
  
  init(bounds: SIMD3<Float>, material: MaterialType, basis: any _Basis.Type) {
    self.basis = basis
    if basis == Cubic.self {
      self.grid = CubicGrid(bounds: bounds, material: material)
    } else if basis == Hexagonal.self {
      self.grid = HexagonalGrid(bounds: bounds, material: material)
    } else {
      fatalError("This should never happen.")
    }
  }
  
  func checkScopesValid(type: LatticeScopeType) {
    if scopes.count > 0 {
      if scopes.first!.type == .volume {
        return
      }
    } else {
      if type == .volume {
        return
      }
    }
    fatalError(
      "Plane algebra operations must be encapsulated inside a Volume scope.")
  }
}

// Functions for pushing/popping items from the stack.
// - Scope
// - Origin (shared among scopes)
extension LatticeStack {
  mutating func withOrigin(_ closure: () -> Void) {
    let currentOrigin = origins.first ?? .zero
    origins.append(currentOrigin)
    closure()
    origins.removeLast()
  }
  
  mutating func withScope(type: LatticeScopeType, _ closure: () -> Void) {
    checkScopesValid(type: type)
    scopes.append(LatticeScope(type: type))
    withOrigin {
      closure()
    }
    
    // Check that a successor exists, and the list is large enough to have a
    // predecessor.
    if let successor = scopes.removeLast().mask, scopes.count > 0 {
      if type.modifiesPredecessor {
        scopes[scopes.count - 1].combine(successor)
      }
    }
  }
}

// Functions for applying operations.
// - Origin
// - Plane

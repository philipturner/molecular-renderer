//
//  Stack.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/15/23.
//

struct LatticeStackDescriptor {
  // The global descriptor resets as soon as it is used.
  static var global: LatticeStackDescriptor = .init()
  
  // The user may only set each of these once.
  var basis: (any _Basis.Type)?
  var bounds: SIMD3<Float>?
  var materialType: MaterialType?
}

// `class` instead of `struct` to overcome an issue with Swift references.
class LatticeStack {
  var basis: any _Basis.Type
  var grid: any LatticeGrid
  var origins: [SIMD3<Float>] = []
  var scopes: [LatticeScope] = []
  
  // Call this before force-unwrapping the value of `.global`.
  static func touchGlobal() {
    guard global == nil else {
      return
    }
    
    let descriptor = LatticeStackDescriptor.global
    guard let basis = descriptor.basis,
          let bounds = descriptor.bounds,
          let materialType = descriptor.materialType else {
      fatalError(
        "Global lattice stack does not exist, and descriptor is incomplete.")
    }
    
    // Reset the global descriptor as soon as it is used.
    LatticeStackDescriptor.global = .init()
    
    // Lazily create a new stack, if all arguments are specified.
    global = LatticeStack(
      basis: basis, bounds: bounds, materialType: materialType)
  }
  
  // Call this instead of setting `.global` to `nil`.
  static func deleteGlobal() {
    // Remove the reference to the current stack. The caller may retain it.
    global = nil
    
    // Reset to ensure the descriptor doesn't pollute future ones.
    LatticeStackDescriptor.global = .init()
  }
  
  // The getter will never return 'nil', so it is okay to force-unwrap. It is
  // only nullable to the setter can be used to destroy it.
  static var global: LatticeStack?
  
  init(
    basis: any _Basis.Type,
    bounds: SIMD3<Float>,
    materialType: MaterialType
  ) {
    self.basis = basis
    if basis == Cubic.self {
      self.grid = CubicGrid(bounds: bounds, materialType: materialType)
    } else if basis == Hexagonal.self {
      self.grid = HexagonalGrid(bounds: bounds, materialType: materialType)
    } else {
      fatalError("This should never happen.")
    }
  }
}

// Functions for pushing/popping items from the stack.
extension LatticeStack {
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
  
  func withOrigin(_ closure: () -> Void) {
    let currentOrigin = origins.last ?? .zero
    origins.append(currentOrigin)
    closure()
    origins.removeLast()
  }
  
  func withScope(type: LatticeScopeType, _ closure: () -> Void) {
    checkScopesValid(type: type)
    scopes.append(LatticeScope(type: type))
    withOrigin {
      closure()
    }
    let successor = scopes.removeLast()
    
    // Check that a successor exists, and the list is large enough to have a
    // predecessor.
    if let mask = successor.mask, scopes.count > 0 {
      if type.modifiesPredecessor {
        scopes[scopes.count - 1].combine(mask)
      }
    }
  }
}

// Functions for applying operations.
extension LatticeStack {
  func checkOriginsValid() {
    guard origins.count > 0 else {
      fatalError("No origins.")
    }
  }
  
  func checkScopesValid() {
    guard scopes.count > 0 else {
      fatalError("No scopes.")
    }
  }
  
  func origin(delta: SIMD3<Float>) {
    checkOriginsValid()
    origins[origins.count - 1] += delta
  }
  
  func plane(normal: SIMD3<Float>) {
    plane(type: basis)
    
    func plane<T: _Basis>(type: T.Type) {
      if all(normal .== 0) {
        fatalError("Plane normal must have a nonzero component.")
      }
      checkOriginsValid()
      let origin = origins.last!
      let mask = T.Grid.Mask(
        dimensions: grid.dimensions, origin: origin, normal: normal)
      
      checkScopesValid()
      scopes[scopes.count - 1].combine(mask)
    }
  }
  
  func createSelectedVolume() -> any LatticeMask {
    checkScopesValid()
    var volume: (any LatticeMask)?
    
    for scope in scopes.reversed() {
      let predecessor = scope
      guard let successor = volume else {
        volume = predecessor.mask
        continue
      }
      volume = predecessor.backpropagate(successor)
    }
    guard let volume else {
      fatalError("Backpropagation produced no volume.")
    }
    return volume
  }
  
  private static func replace<G: LatticeGrid>(
    grid: inout G, other: Int8, volume: any LatticeMask
  ) {
    guard let volume = volume as? G.Mask else {
      fatalError("Combined lattices of different types.")
    }
    grid.replace(with: other, where: volume)
  }
  
  func replace(with other: Int8) {
    Self.replace(
      grid: &grid,
      other: other,
      volume: createSelectedVolume())
  }
}

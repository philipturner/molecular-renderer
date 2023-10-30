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

// `class` instead of `struct` to overcome an issue with Swift references.
class LatticeStack {
  var grid: any LatticeGrid
  var basis: any _Basis.Type
  var scopes: [LatticeScope] = []
  var origins: [SIMD3<Float>] = []
  
  // Call this before force-unwrapping the value of `.global`.
  static func touchGlobal() {
    guard global == nil else {
      return
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
    global = LatticeStack(bounds: bounds, material: material, basis: basis)
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
    
    // NOTE: There is a bug. When a Volume is nested inside a Concave, it
    // won't treat it like it's actually concave. Or, something is messed up
    // with the origin. Reproducer:
//    Concave {
//      Origin { 2.8 * l }
//      Plane { l }
//      Volume {
//        Origin { -2.5 * h2k }
//        Plane { -h2k }
//        Replace { .empty }
//      }
//    }
    
    // Second reproducer: when disconnecting this from the parent's scope
    // (duplicating the "Origin { 12 * h + 8 * h2k + 6 * l }" statement), the
    // geometry started behaving predictably again.
//    Volume {
//      Concave {
//        for direction in [h, -h] {
//          Convex {
//            if direction.x > 0 {
//              Origin { 4 * direction }
//            } else {
//              Origin { 3.5 * direction }
//            }
//            Plane { -direction }
//          }
//        }
//        Concave {
//          Origin { -1.2 * l }
//          Plane { l }
//          Origin { 2 * l }
//          Plane { -l }
//          
//          Origin { -5.5 * h2k }
//          Plane { -h2k }
//        }
//      }
//      Replace { .empty }
//    }
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

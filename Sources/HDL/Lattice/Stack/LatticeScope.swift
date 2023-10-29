//
//  LatticeScope.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/29/23.
//

enum LatticeScopeType {
  case concave
  case convex
  case volume
  
  var modifiesPredecessor: Bool {
    self != .volume
  }
  
  var usesLogicalAnd: Bool {
    self == .concave
  }
}

struct LatticeScope {
  var type: LatticeScopeType
  private(set) var mask: (any LatticeMask)?
  
  init(type: LatticeScopeType) {
    self.type = type
  }
  
  mutating func combine<T: LatticeMask>(_ other: T) {
    guard let maskCopy = mask else {
      // If no mask exists, simply replace with the passed-in mask.
      mask = other
      return
    }
    guard let maskCopy = maskCopy as? T else {
      fatalError("Combined lattices of different types.")
    }
    
    // Due to some implementation issues, a new Swift array will be allocated
    // every time, instead of just writing to the old array in-place.
    if type.usesLogicalAnd {
      mask = maskCopy & other
    } else {
      mask = maskCopy | other
    }
  }
  
  // There is no way to cache the accumulated mask, as the summation must go
  // from deepest to shallowest tree level. Each backpropagation could be either
  // AND or OR, depending on whether the scope is concave. Backpropagation
  // starts at the deepest scope with a non-empty mask.
  func backpropagate<T: LatticeMask>(
    _ successor: T
  ) -> any LatticeMask {
    // If the current scope's mask doesn't exist, both AND and OR are identity
    // operations on the successor.
    let predecessor = self.mask ?? successor
    guard let predecessor = predecessor as? T else {
      fatalError("Combined lattices of different types.")
    }
    
    // During the backpropagation, 'Volume' scopes are treated like 'Convex'.
    // This is different than the behavior when they're popped from the stack.
    // No line of code in this function body explicitly enables such behavior
    // (the only reference to 'type' is the predecessor's type, rather than the
    // successor's type). Rather, the behavior is enabled by not erasing the
    // effects of a 'Volume'.
    if type.usesLogicalAnd {
      return predecessor & successor
    } else {
      return predecessor | successor
    }
  }
}

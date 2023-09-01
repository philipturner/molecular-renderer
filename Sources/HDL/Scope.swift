//
//  Scope.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/1/23.
//

// MARK: - Scopes

public protocol Scope: Transform {
  
}

// Any transform may be called inside this.
public struct Solid: Scope, ConstructiveTransform {
  public func callAsFunction() -> SolidCopy {
    fatalError("Not implemented.")
  }
}

// Only destructive or neutral transforms may be called inside this. Enforce
// this restriction through generic type constraints.
public struct Convex: Scope, DestructiveTransform {
  
}

// Only destructive or neutral transforms may be called inside this. Enforce
// this restriction through generic type constraints.
public struct Concave: Scope, DestructiveTransform {
  
}

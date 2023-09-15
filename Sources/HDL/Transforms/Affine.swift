//
//  Affine.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/1/23.
//

// MARK: - Transforms

// Cuts cannot happen during a transform; transforms cannot happen inside a
// 'Volume'.
public struct Affine {
  @discardableResult
  public init(_ closure: () -> Void) {
    
  }
}

public protocol AffineTransform { }

public struct Reflect: AffineTransform {
  @discardableResult
  public init<T>(_ closure: () -> Vector<T>) {
    
  }
}

public struct Rotate: AffineTransform {
  @discardableResult
  public init<T>(_ closure: () -> Vector<T>) {
    
  }
}

public struct Translate: AffineTransform {
  @discardableResult
  public init<T>(_ closure: () -> Vector<T>) {
    
  }
}

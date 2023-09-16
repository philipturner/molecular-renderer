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
    Compiler.global.startAffine()
    closure()
    Compiler.global.endAffine()
  }
}

public protocol AffineTransform { }

public struct Reflect: AffineTransform {
  @discardableResult
  public init(_ closure: () -> Vector<Cubic>) {
    Compiler.global.performReflect(closure().simdValue)
  }
  
  @discardableResult
  public init(_ closure: () -> Vector<Hexagonal>) {
    fatalError("Not implemented.")
  }
}

public struct Rotate: AffineTransform {
  @discardableResult
  public init(_ closure: () -> Vector<Cubic>) {
    Compiler.global.performRotate(closure().simdValue)
  }
  
  @discardableResult
  public init(_ closure: () -> Vector<Hexagonal>) {
    fatalError("Not implemented.")
  }
}

public struct Translate: AffineTransform {
  @discardableResult
  public init(_ closure: () -> Vector<Cubic>) {
    Compiler.global.performTranslate(closure().simdValue)
  }
  
  @discardableResult
  public init(_ closure: () -> Vector<Hexagonal>) {
    fatalError("Not implemented.")
  }
}

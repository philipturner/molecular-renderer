//
//  Plane.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/29/23.
//

public struct Plane {
  @discardableResult
  public init<T>(_ closure: () -> Vector<T>) {
    if T.self == Cubic.self {
      Compiler.global.addPlane(closure().simdValue)
    } else {
      fatalError("Not implemented.")
    }
  }
}

/// Unions of infinite planes for extruding slanted and curved surfaces.
protocol PlanePair {
  /// Initialize a type conforming to the plane pair protocol.
  /// - Parameter original: The vector normal to the first plane.
  /// - Parameter closure: The vector to reflect the first plane's normal
  ///   across, when generating the second plane.
  @discardableResult
  init<T>(_ original: Vector<T>, _ closure: () -> Vector<T>)
}

extension PlanePair {
  /// Reflection is a linear transformation, so this function works correctly
  /// in a non-orthonormal basis like `Hexagonal`.
  fileprivate static func applyDirections<T>(
    _ original: Vector<T>, _ closure: () -> Vector<T>
  ) {
    func normalize(_ x: SIMD3<Float>) -> SIMD3<Float> {
      let length = (x * x).sum().squareRoot()
      return length == 0 ? .zero : (x / length)
    }
    let reflector = normalize(closure().simdValue)
    Plane { original }
    
    /// For the incident vector `I` and surface orientation `N`, compute
    /// normalized `N (NN)`, and return the reflection direction:
    /// `I - 2 * dot(NN, I) * NN`.
    func reflect(i: SIMD3<Float>, n: SIMD3<Float>) -> SIMD3<Float> {
      i - 2 * (n * i).sum() * n
    }
    let reflected = -reflect(i: original.simdValue, n: reflector)
    Plane { Vector<T>(simdValue: reflected) }
  }
}

public struct Ridge: PlanePair {
  @discardableResult
  public init<T>(_ original: Vector<T>, _ closure: () -> Vector<T>) {
    Convex {
      Self.applyDirections(original, closure)
    }
  }
}

public struct Valley: PlanePair {
  @discardableResult
  public init<T>(_ original: Vector<T>, _ closure: () -> Vector<T>) {
    Concave {
      Self.applyDirections(original, closure)
    }
  }
}

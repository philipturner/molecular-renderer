//
//  PlanePair.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

/// Unions of infinite planes for extruding slanted and curved surfaces.
///
/// These may be extracted into a separate module in the future.
public protocol PlanePair {
  /// Initialize a type conforming to the plane pair protocol.
  /// - Parameter original: The vector normal to the first plane.
  /// - Parameter closure: The vector to reflect the first plane's normal
  ///   across, when generating the second plane.
  @discardableResult
  init<T>(_ original: Vector<T>, _ closure: () -> Vector<T>)
}

extension PlanePair {
  fileprivate static func applyDirections<T>(
    _ original: Vector<T>, _ closure: () -> Vector<T>
  ) {
    let reflector = closure()
    Plane { original }
    
    func dot(_ x: SIMD3<Float>, _ y: SIMD3<Float>) -> Float {
      (x * y).sum()
    }
    
    /// For the incident vector `I` and surface orientation `N`, compute
    /// normalized `N (NN)`, and return the reflection direction:
    /// `I - 2 * dot(NN, I) * NN`.
    func reflect(i: SIMD3<Float>, n: SIMD3<Float>) -> SIMD3<Float> {
      i - 2 * dot(n, i) * n
    }
    
    let reflected = -reflect(i: original.simdValue, n: reflector.simdValue)
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

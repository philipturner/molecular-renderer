//
//  Plane.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/29/23.
//

public struct Plane {
  @discardableResult
  public init(_ closure: () -> SIMD3<Float>) {
    guard GlobalScope.global == .lattice else {
      GlobalScope.throwUnrecognized(Self.self)
    }
    LatticeStack.touchGlobal()
    LatticeStack.global!.plane(normal: closure())
  }
}

/// Unions of infinite planes for extruding slanted and curved surfaces.
protocol PlanePair {
  /// Initialize a type conforming to the plane pair protocol.
  /// - Parameter original: The vector normal to the first plane.
  /// - Parameter closure: The vector to reflect the first plane's normal
  ///   across, when generating the second plane.
  @discardableResult
  init(_ normal: SIMD3<Float>, _ closure: () -> SIMD3<Float>)
}

extension PlanePair {
  /// Reflection is a linear transformation, so this function works correctly
  /// in a non-orthonormal basis like `Hexagonal`.
  fileprivate static func applyDirections(
    _ normal: SIMD3<Float>, _ closure: () -> SIMD3<Float>
  ) {
    Plane { normal }
    
    func normalize(_ x: SIMD3<Float>) -> SIMD3<Float> {
      let length = (x * x).sum().squareRoot()
      return length == 0 ? .zero : (x / length)
    }
    let reflector = normalize(closure())
    
    /// For the incident vector `I` and surface orientation `N`, compute
    /// normalized `N (NN)`, and return the reflection direction:
    /// `I - 2 * dot(NN, I) * NN`.
    func reflect(i: SIMD3<Float>, n: SIMD3<Float>) -> SIMD3<Float> {
      i - 2 * (n * i).sum() * n
    }
    Plane { -reflect(i: normal, n: reflector) }
  }
}

public struct Ridge: PlanePair {
  @discardableResult
  public init(_ normal: SIMD3<Float>, _ closure: () -> SIMD3<Float>) {
    Convex {
      Self.applyDirections(normal, closure)
    }
  }
}

public struct Valley: PlanePair {
  @discardableResult
  public init(_ normal: SIMD3<Float>, _ closure: () -> SIMD3<Float>) {
    Concave {
      Self.applyDirections(normal, closure)
    }
  }
}

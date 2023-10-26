//
//  Solid.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

public struct Solid {
  var centers: [SIMD3<Float>] = []
  
  /// Unstable API; do not use this function.
  ///
  /// Right now, returns centers in the diamond `Cubic` basis. They are measured
  /// in multiples of 0.357 nm, not in nanometers.
  public var _centers: [SIMD3<Float>] { centers }
  
  // TODO: Change to Vector<Amorphous>
  public init(_ closure: (
    SIMD3<Float>, SIMD3<Float>, SIMD3<Float>
  ) -> Void) {
    Compiler.global.startSolid()
    closure(SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1))
    self.centers = Compiler.global.endSolid()
  }
}

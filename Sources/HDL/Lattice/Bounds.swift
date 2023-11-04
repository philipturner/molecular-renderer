//
//  Bounds.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/16/23.
//

public struct Bounds {
  // Compiler bug: not cutting hexagonal bounds correctly. Reproducer:
  //  let lattice = Lattice<Hexagonal> { h, k, l in
  //    let h2k = h + 2 * k
  //    Bounds { 9 * h + 7 * h2k + 15 * l }
  //    Material { .elemental(.carbon) }
  //
  //    Volume {
  //      Concave {
  //        Origin { 3 * h + 4.5 * h2k }
  //        Plane { -h }
  //        Plane { -h2k }
  //      }
  //      Concave {
  //        Origin { 6 * h + 4.5 * h2k }
  //        Plane { h }
  //        Plane { -h2k }
  //      }
  //
  //      Replace { .empty }
  //    }
  //  }
  @discardableResult
  public init(_ closure: () -> SIMD3<Float>) {
    let bounds = closure()
    let remainder = bounds - bounds.rounded(.down)
    guard all(remainder .== 0) else {
      fatalError("Bounds were not integers.")
    }
    
    guard LatticeStackDescriptor.global.bounds == nil else {
      fatalError("Already set bounds.")
    }
    LatticeStackDescriptor.global.bounds = bounds
  }
}

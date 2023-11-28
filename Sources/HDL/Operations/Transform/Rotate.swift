//
//  Rotate.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/29/23.
//

public struct Rotate {
  @discardableResult
  public init(_ rotation: Float, _ closure: () -> SIMD3<Float>) {
    let input = closure()
    var axis = SIMD3(input.x, input.y, input.z)
    guard !all(axis .== 0) else {
      fatalError("Direction must not be all zeroes.")
    }
    axis /= (axis * axis).sum().squareRoot()
    
    guard var rotation = Optional(rotation), rotation != 0 else {
      fatalError("Rotation must not be zero.")
    }
    rotation -= rotation.rounded(.down)
    rotation *= 2 * Float.pi
    
    fatalError("Not implemented.")
  }
}

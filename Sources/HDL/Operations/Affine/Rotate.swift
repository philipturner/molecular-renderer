//
//  Rotate.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/29/23.
//

import RealModule
import QuaternionModule

public struct Rotate {
  @discardableResult
  public init(_ closure: () -> SIMD4<Float>) {
    let input = closure()
    var direction = SIMD3(input.x, input.y, input.z)
    guard !all(direction .== 0) else {
      fatalError("Direction must not be all zeroes.")
    }
    direction /= (direction * direction).sum().squareRoot()
    
    var rotation = input.w
    guard rotation != 0 else {
      fatalError("Rotation must not be zero.")
    }
    rotation -= rotation.rounded(.down)
    rotation *= 2 * Float.pi
    
    self.init {
      Quaternion<Float>.init(angle: rotation, axis: direction)
    }
  }
  
  @discardableResult
  public init(_ closure: () -> Quaternion<Float>) {
    fatalError("Not implemented.")
  }
}

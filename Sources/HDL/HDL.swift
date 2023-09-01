//
//  HDL.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/28/23.
//

import QuaternionModule

// MARK: - Environment Objects

public class GeometryCompiler {
  public let global: GeometryCompiler = GeometryCompiler()
  
  public init() {
    // Resets the scene after the popping the stack of the outermost
    // 'Solid' scope.
  }
}

// Multiple directions/positions sourced from the same axis may not be called
// when generating a single cut or translation.
public struct Axis {
  public static let X = Axis()
  public static let Y = Axis()
  public static let Z = Axis()
  
  internal init(/*arguments*/) {
    
  }
  
  static prefix func + (rhs: Axis) -> Direction {
    fatalError("Not implemented.")
  }
  
  static prefix func - (rhs: Axis) -> Direction {
    fatalError("Not implemented.")
  }
  
  static func * (lhs: Float, rhs: Axis) -> Position {
    fatalError("Not implemented.")
  }
}

public struct Direction {
  
}

public struct Position {
  
}

//
//  Axis.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

// RidgeCut and ValleyCut will accept anything conforming to this protocol.
public protocol AxisProtocol {
  
}

// Multiple directions/positions sourced from the same axis may not be called
// when generating a single cut or translation.
public struct Axis: AxisProtocol {
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
  
  
  // Creates a new axis specified by combining these directions in a specific
  // order. If not following the right-hand rule, one axis's sign will be
  // reversed.
  //
  // Not sure how to support ridge/valley cuts along (111) planes yet.
  static func ^ (lhs: Axis, rhs: Axis) -> CombinedAxis {
    fatalError("Not implemented.")
  }
}

public struct CombinedAxis: AxisProtocol {
  
}

public struct Direction {
  
}

public struct Position {
  
}

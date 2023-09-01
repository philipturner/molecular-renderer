//
//  Axis.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

// RidgeCut and ValleyCut will accept anything conforming to this protocol.
public protocol AxisProtocol {
  
}

public protocol DirectionProtocol {
  
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
}

// Fix this. Ridge/Valley cut should accept either z or +z, just
// providing an option to omit the sign for simplicity.
//
// Ridge/Valley accept either an axis or a direction.
public struct CombinedDirection: AxisProtocol, DirectionProtocol {
  
}

public struct Direction {
  static func ^ (lhs: Direction, rhs: Direction) -> CombinedDirection {
    fatalError("Not implemented.")
  }
}

public struct Position {
  
}

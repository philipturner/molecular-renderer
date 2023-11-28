//
//  Element.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/22/23.
//

/// The elements supported by MM4.
public enum Element: UInt8, CustomStringConvertible {
  case hydrogen = 1
  case carbon = 6
  case nitrogen = 7
  case oxygen = 8
  case fluorine = 9
  case silicon = 14
  case phosphorus = 15
  case sulfur = 16
  case germanium = 32
  
  @inlinable @inline(__always)
  public init(_ atomicNumber: UInt8) {
    self.init(rawValue: atomicNumber)!
  }
  
  public var description: String {
    switch self {
    case .hydrogen: return ".hydrogen"
    case .carbon: return ".carbon"
    case .nitrogen: return ".nitrogen"
    case .oxygen: return ".oxygen"
    case .fluorine: return ".fluorine"
    case .silicon: return ".silicon"
    case .phosphorus: return ".phosphorus"
    case .sulfur: return ".sulfur"
    case .germanium: return ".germanium"
    }
  }
}

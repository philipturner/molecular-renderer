//
//  Material.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/26/23.
//

// MARK: - Types

public enum MaterialType {
  case elemental(Element)
  case checkerboard(Element, Element)
}

public enum ConstantType {
  case hexagon
  case prism
  case square
  
  var latticeMultiplier: Float {
    switch self {
    case .hexagon:
      return Float(1.0 / 2).squareRoot()
    case .prism:
      return Float(4.0 / 3).squareRoot()
    case .square:
      return 1
    }
  }
}

// MARK: - Keywords

public struct Material {
  @discardableResult
  public init(_ closure: () -> MaterialType) {
    guard GlobalScope.global == .lattice else {
      GlobalScope.throwUnrecognized(Self.self)
    }
    
    let materialType = closure()
    switch materialType {
    case .elemental(let element):
      switch element {
      case .carbon: break
      case .silicon: break
      case .germanium: break
      default: fatalError("Unrecognized material type: \(materialType)")
      }
    case .checkerboard(let a, let b):
      let minElement = (a.rawValue < b.rawValue) ? a : b
      let maxElement = (a.rawValue > b.rawValue) ? a : b
      switch (minElement, maxElement) {
      case (.carbon, .silicon): break
      case (.carbon, .germanium): break
      default: fatalError("Unrecognized material type: \(materialType)")
      }
    }
    
    guard LatticeStackDescriptor.global.materialType == nil else {
      fatalError("Already set material.")
    }
    LatticeStackDescriptor.global.materialType = materialType
  }
}

public typealias Constant = Float

extension Float {
  /// Do not use this initializer via the API `Float.init`. It is intended to be
  /// used through the API `Constant.init`.
  public init(
    _ constantType: ConstantType,
    _ closure: () -> MaterialType
  ) {
    let materialType = closure()
    var cubicSpacing: Float
    switch materialType {
    case .elemental(.carbon):
      cubicSpacing = 0.3567
    case .checkerboard(.carbon, .silicon),
        .checkerboard(.silicon, .carbon):
      cubicSpacing = 0.4360
    case .checkerboard(.carbon, .germanium),
        .checkerboard(.germanium, .carbon):
      cubicSpacing = 0.4523
    case .elemental(.silicon):
      cubicSpacing = 0.5431
    case .elemental(.germanium):
      cubicSpacing = 0.5658
    default:
      fatalError("Unrecognized material type: \(materialType)")
    }
    
    self = cubicSpacing * constantType.latticeMultiplier
  }
}

//
//  Material.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/26/23.
//

public struct Material {
  @discardableResult
  public init(_ closure: () -> MaterialType) {
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

public enum MaterialType {
  case elemental(Element)
  case checkerboard(Element, Element)
  
  /// Used internally to adjust the lattice spacing.
  var bondLength: Float {
    switch self {
    case .elemental(let element):
      switch element {
      case .carbon: return 1.5270
      case .silicon: return 2.322
      case .germanium: return 2.404
      default: fatalError("Unrecognized material: \(self)")
      }
    case .checkerboard(let a, let b):
      let minElement = (a.rawValue < b.rawValue) ? a : b
      let maxElement = (a.rawValue > b.rawValue) ? a : b
      switch (minElement, maxElement) {
      case (.carbon, .silicon): return 1.876
      case (.carbon, .germanium): return 1.949
      default: fatalError("Unrecognized material: \(self)")
      }
    }
  }
}

// Make an API that ends up used internally to LatticeGrid.
//
// Diamond:           cubic = 0.3567
// Silicon Carbide:   cubic = 0.4360
// Germanium Carbide: cubic = 0.4523
// Silicon:           cubic = 0.5431
// Germanium:         cubic = 0.5658

/*
 let carbonBondLength = MaterialType.elemental(.carbon).bondLength
 squareSideLength = 0.357
 squareSideLength *= material.bondLength / carbonBondLength
 */

/*
 // Base the lattice constants on diamond, so it can intermix perfectly in
 // mixed-phase crystalline structures.
 // a: 2.51 -> 2.52
 // c: 4.12 -> 4.12
 let carbonBondLength = MaterialType.elemental(.carbon).bondLength
 hexagonSideLength = Float(1.0 / 2).squareRoot() * 0.357
 prismHeight = Float(4.0 / 3).squareRoot() * 0.357
 hexagonSideLength *= material.bondLength / carbonBondLength
 prismHeight *= material.bondLength / carbonBondLength
 */

/*
 ```swift
 Constant<Basis>(Basis.ConstantType) { MaterialType }
 let latticeConstant = Constant<Cubic>(.square) { .elemental(.carbon) }

 Cubic.ConstantType.square // square side length
 Hexagonal.ConstantType.hexagon // hexagon side length
 Hexagonal.ConstantType.prism // prism height
 ```
 */

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

fileprivate func cubicSpacing(material: MaterialType) -> Float {
  switch material {
  case .elemental(.carbon):
    return 0.3567
  case .checkerboard(.carbon, .silicon),
      .checkerboard(.silicon, .carbon):
    return 0.4360
  case .checkerboard(.carbon, .germanium),
      .checkerboard(.germanium, .carbon):
    return 0.4523
  case .elemental(.silicon):
    return 0.5431
  case .elemental(.germanium):
    return 0.5658
  default:
    fatalError("Unrecognized material type: \(material)")
  }
}

public struct Constant {
  @discardableResult
  public init(_ constantType: ConstantType, _ closure: () -> MaterialType) {
    let materialType = closure()
    fatalError("Not implemented.")
  }
}

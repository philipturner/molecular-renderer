//
//  Material.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

public enum Bond {
  case single
  case double
  case triple
  case fractional(Int, Int) // TODO: Better solution for graphene
}

public enum Element: Int {
  case hydrogen = 1
  case carbon = 6
  case silicon = 14
  case germanium = 32
  
  public init(_ atomicNumber: Int) {
    self.init(rawValue: atomicNumber)!
  }
}

public struct Material {
  @discardableResult
  public init(_ closure: () -> HDL.Element) {
    self.init { [closure()] }
  }
  
  @discardableResult
  public init(_ closure: () -> [HDL.Element]) {
    let elements = closure()
    if elements.count == 1 {
      switch elements[0] {
      case .carbon:
        // carbon
        break
      case .silicon:
        // silicon
        fatalError("Elemental silicon not supported yet.")
        break
      case .germanium:
        // germanium
        fatalError("Elemental germanium not supported yet.")
        break
      default:
        fatalError("Unrecognized element: \(elements[0])")
      }
    } else if elements.count == 2 {
      var element1 = elements[0]
      var element2 = elements[1]
      if element1 == element2 {
        fatalError("Elements cannot be the same.")
      }
      if element1.rawValue > element2.rawValue {
        swap(&element1, &element2)
      }
      
      // NOTE: Order does matter. The first element in the list should be the
      // element that appears at (0, 0, 0).
      switch (element1, element2) {
      case (.carbon, .silicon):
        // silicon carbide
        fatalError("Moissanite not supported yet.")
        break
      default:
        fatalError("Unrecognized elements: \(element1), \(element2)")
      }
    } else {
      fatalError("Invalid element count: \(elements.count). Expected 1 or 2.")
    }
  }
}

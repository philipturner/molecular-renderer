//
//  Material.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

public enum MaterialType {
  case elemental(Element)
  case checkerboard(Element, Element)
}

public struct Material {
  @discardableResult
  public init(_ closure: () -> MaterialType) {
    let type = closure()
    switch type {
    case .elemental(let element):
      switch element {
      case .carbon: break
      case .silicon: break
      case .germanium: break
      default: fatalError("Unrecognized material: \(type)")
      }
    case .checkerboard(let a, let b):
      let minElement = (a.rawValue < b.rawValue) ? a : b
      let maxElement = (a.rawValue > b.rawValue) ? a : b
      switch (minElement, maxElement) {
      case (.carbon, .silicon): break
      case (.carbon, .germanium): break
      default: fatalError("Unrecognized material: \(type)")
      }
    }
  }
}

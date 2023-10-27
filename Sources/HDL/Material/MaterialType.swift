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

extension MaterialType {
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

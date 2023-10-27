//
//  Material.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/26/23.
//

public struct Material {
  @discardableResult
  public init(_ closure: () -> MaterialType) {
    let material = closure()
    switch material {
    case .elemental(let element):
      switch element {
      case .carbon: break
      case .silicon: break
      case .germanium: break
      default: fatalError("Unrecognized material: \(material)")
      }
    case .checkerboard(let a, let b):
      let minElement = (a.rawValue < b.rawValue) ? a : b
      let maxElement = (a.rawValue > b.rawValue) ? a : b
      switch (minElement, maxElement) {
      case (.carbon, .silicon): break
      case (.carbon, .germanium): break
      default: fatalError("Unrecognized material: \(material)")
      }
    }
    
    guard LatticeStackDescriptor.global.material == nil else {
      fatalError("Already set material.")
    }
    LatticeStackDescriptor.global.material = material
  }
}

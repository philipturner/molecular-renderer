//
//  AtomicMasses.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/10/23.
//

import Foundation

#if false

// MARK: - Force Field Statistics

class AtomicMasses {
  // Mass of each element on the periodic table, in kg.
  private var elements: Vector<Double>
  
  init() {
    elements = .init(repeating: 0, count: 119, alignment: 1)
    
    let amuToGrams = 1 / Double(6.022e23)
    let amuToKg = amuToGrams / 1000
    elements.setElement(4.002602 * amuToKg, index: 2)
    elements.setElement(20.1797 * amuToKg, index: 10)
    elements.setElement(39.948 * amuToKg, index: 18)
    elements.setElement(83.798 * amuToKg, index: 36)
  }
  
  @inline(__always)
  func getMass(atomicNumber: UInt8) -> Double {
    self.elements.getElement(index: Int(atomicNumber))
  }
}

#endif

//
//  Replace.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

// Precedence for de-duplicating during Copy:
// - Carbon or silicon, whichever comes from the newer crystal
// - Single bond or hydrogen, whichever comes from the newer crystal
// - Empty space
public struct Replace {
  @discardableResult
  public init(_ closure: () -> Element) {
    fatalError("Not implemented.")
  }
  
  @discardableResult
  public init(_ closure: () -> [Element]) {
    // Order of elements should matter for Moissanite, just like with Material.
    fatalError("Not implemented.")
  }
  
  @discardableResult
  public init(_ closure: () -> Bond) {
    fatalError("Not implemented.")
  }
}

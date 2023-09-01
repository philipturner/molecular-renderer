//
//  Crystal.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/1/23.
//

// While inside a lattice, all translations and rotations must perfectly align
// with the lattice. That way, atoms can be de-duplicated when fusing through
// constructive solid geometry. After breaking out of the lattice, covalent
// bonds are formed and surfaces are passivated. Atoms can't be de-duplicated
// anymore. However, the same types of transforms can be performed on atoms in
// bulk.
public struct Lattice<T: Basis> {
  public init(_ closure: () -> Void) {
    
  }
}

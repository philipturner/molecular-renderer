//
//  Basis.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

public protocol Basis {
  
}

public protocol CrystalBasis: Basis {
  
}

public struct Amorphous: Basis {
  
}

public struct Cubic: CrystalBasis {
  
}

public struct Hexagonal: CrystalBasis {
  
}

// Used for cutting hexagonal lattices.
public let a = Vector<Hexagonal>(x: .nan, y: .nan, z: .nan)
public let b = Vector<Hexagonal>(x: .nan, y: .nan, z: .nan)
public let c = Vector<Hexagonal>(x: .nan, y: .nan, z: .nan)

// Used for cutting cubic lattices and defining the positions of objects.
public let h = Vector<Cubic>(x: 1, y: 0, z: 0)
public let k = Vector<Cubic>(x: 0, y: 1, z: 0)
public let l = Vector<Cubic>(x: 0, y: 0, z: 1)

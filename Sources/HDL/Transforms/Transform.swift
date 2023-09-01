//
//  Transform.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/1/23.
//

// MARK: - Transforms

// Cannot perform any transforms until a solid generator is called.
public protocol Transform {
  
}

// Constructive solid geometry; combining multiple solids. Also attributed to
// neutral transforms to simplify the generic type requirements.
public protocol ConstructiveTransform: Transform {
  
}

// Disjunctive normal form on planes; AND and OR logic.
public protocol DestructiveTransform: Transform {
  
}

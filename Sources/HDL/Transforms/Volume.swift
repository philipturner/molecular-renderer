//
//  Volume.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

// Origin translations always reset when a scope ends, but volumes don't.
// Rather, the application of the current logical operator (AND, OR) gets popped
// from the stack. Volume prevents volumes from leaking outside.
//
// This can be nested, if you want to prevent changes happening in two layers
// of Convex or Concave from propagating to the outer scope - ???
public struct Volume {
  @discardableResult
  public init(_ closure: () -> Void) {
    
  }
}

public protocol VolumeTransform { }

// Removes atoms along the plane (origin, normal) where the normal is entered
// into the initializer.
public struct Plane: VolumeTransform {
  @discardableResult
  public init<T>(_ closure: () -> Direction<T>) {
    
  }
}

// Every time a volume is added, previous volumes are combined with OR. This is
// a no-op, except that it resets translations of the origin.
public struct Convex: VolumeTransform {
  @discardableResult
  public init(_ closure: () -> Void) {
    
  }
}


// Every time a volume is added, previous volumes are combined with AND.
public struct Concave: VolumeTransform {
  @discardableResult
  public init(_ closure: () -> Void) {
    
  }
}

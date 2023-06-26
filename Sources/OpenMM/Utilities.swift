//
//  Utilities.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 6/25/23.
//

import COpenMM

@inline(__always)
func _openmm_create(
  _ closure: @convention(c) () -> OpaquePointer?
) -> OpaquePointer {
  guard let result = closure() else {
    fatalError("Could not initialize.")
  }
  return result
}

@inline(__always)
func _openmm_create<T>(
  _ argument1: T,
  _ closure: (T) -> OpaquePointer?
) -> OpaquePointer {
  guard let result = closure(argument1) else {
    fatalError("Could not initialize.")
  }
  return result
}

@inline(__always)
func _openmm_create<T, U>(
  _ argument1: T,
  _ argument2: U,
  _ closure: (T, U) -> OpaquePointer?
) -> OpaquePointer {
  guard let result = closure(argument1, argument2) else {
    fatalError("Could not initialize.")
  }
  return result
}

@inline(__always)
func _openmm_create<T, U, V>(
  _ argument1: T,
  _ argument2: U,
  _ argument3: V,
  _ closure: (T, U, V) -> OpaquePointer?
) -> OpaquePointer {
  guard let result = closure(argument1, argument2, argument3) else {
    fatalError("Could not initialize.")
  }
  return result
}

@inline(__always)
func _openmm_get<S>(
  _ caller: OpaquePointer,
  _ closure: (OpaquePointer?) -> S?,
  function: StaticString = #function
) -> S {
  guard let result = closure(caller) else {
    fatalError("Could not retrieve property '\(function)'.")
  }
  return result
}

@inline(__always)
func _openmm_index_get<S>(
  _ caller: OpaquePointer,
  _ index: Int,
  _ closure: (OpaquePointer?, Int32) -> S?,
  function: StaticString = #function
) -> S {
  let _index = Int32(truncatingIfNeeded: index)
  guard let result = closure(caller, _index) else {
    fatalError("Index out of bounds.")
  }
  return result
}

// _openmm_index_set

@inline(__always)
func _openmm_get<S, T, U>(
  _ caller: OpaquePointer,
  _ argument1: T,
  _ argument2: U,
  _ closure: (OpaquePointer?, T, U) -> S?,
  function: StaticString = #function
) -> S {
  guard let result = closure(caller, argument1, argument2) else {
    fatalError("Could not retrieve property '\(function)'.")
  }
  return result
}

@inline(__always)
func _openmm_get<S, T, U, V>(
  _ caller: OpaquePointer,
  _ argument1: T,
  _ argument2: U,
  _ argument3: V,
  _ closure: (OpaquePointer?, T, U, V) -> S?,
  function: StaticString = #function
) -> S {
  guard let result = closure(caller, argument1, argument2, argument3) else {
    fatalError("Could not retrieve property '\(function)'.")
  }
  return result
}

@inline(never)
func _openmm_no_getter(
  function: StaticString = #function
) -> Never {
  fatalError("The property '\(function)' has no getter.")
}

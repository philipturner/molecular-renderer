//
//  OpenMM_Array.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/25/23.
//

import COpenMM

public class OpenMM_BondArray: OpenMM_Object {
  public convenience init(size: Int) {
    self.init(_openmm_create(Int32(size), OpenMM_BondArray_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_BondArray_destroy(pointer)
  }
  
  public func append(_ particles: SIMD2<Int>) {
    OpenMM_BondArray_append(pointer, Int32(particles[0]), Int32(particles[1]))
  }
  
  public var size: Int {
    let _size = OpenMM_BondArray_getSize(pointer)
    return Int(_size)
  }
  
  public subscript(index: Int) -> SIMD2<Int> {
    get {
      var particle1: Int32 = -1
      var particle2: Int32 = -1
      OpenMM_BondArray_get(pointer, Int32(index), &particle1, &particle2)
      precondition(particle1 > -1 && particle2 > -1, "Invalid indices.")
      
      return SIMD2(Int(particle1), Int(particle2))
    }
    set {
      let particle1 = Int32(newValue[0])
      let particle2 = Int32(newValue[1])
      OpenMM_BondArray_set(pointer, Int32(index), particle1, particle2)
    }
  }
}

public class OpenMM_DoubleArray: OpenMM_Object {
  public convenience init(size: Int) {
    self.init(_openmm_create(Int32(size), OpenMM_DoubleArray_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_DoubleArray_destroy(pointer)
  }
  
  public func append(_ value: Double) {
    OpenMM_DoubleArray_append(pointer, value)
  }
  
  public var size: Int {
    let _size = OpenMM_DoubleArray_getSize(pointer)
    return Int(_size)
  }
  
  public subscript(index: Int) -> Double {
    get {
      _openmm_index_get(pointer, index, OpenMM_DoubleArray_get)
    }
    set {
      OpenMM_DoubleArray_set(pointer, Int32(index), newValue)
    }
  }
}

public class OpenMM_IntArray: OpenMM_Object {
  public convenience init(size: Int) {
    self.init(_openmm_create(Int32(size), OpenMM_IntArray_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_IntArray_destroy(pointer)
  }
  
  public func append(_ value: Int) {
    OpenMM_IntArray_append(pointer, Int32(value))
  }
  
  public var size: Int {
    let _size = OpenMM_IntArray_getSize(pointer)
    return Int(_size)
  }
  
  public subscript(index: Int) -> Int {
    get {
      Int(_openmm_index_get(pointer, index, OpenMM_IntArray_get))
    }
    set {
      OpenMM_IntArray_set(pointer, Int32(index), Int32(newValue))
    }
  }
}

public class OpenMM_StringArray: OpenMM_Object {
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_StringArray_destroy(pointer)
  }
  
  public var size: Int {
    let _size = OpenMM_StringArray_getSize(pointer)
    return Int(_size)
  }
  
  public subscript(index: Int) -> String {
    get {
      .init(cString: _openmm_index_get(pointer, index, OpenMM_StringArray_get))
    }
    // `set` not supported yet.
  }
}

public class OpenMM_Vec3Array: OpenMM_Object {
  public convenience init(size: Int) {
    self.init(_openmm_create(Int32(size), OpenMM_Vec3Array_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_Vec3Array_destroy(pointer)
  }
  
  public func append(_ vec: SIMD3<Double>) {
    let _vector = OpenMM_Vec3(x: vec.x, y: vec.y, z: vec.z)
    OpenMM_Vec3Array_append(pointer, _vector)
  }
  
  public var size: Int {
    let _size = OpenMM_Vec3Array_getSize(pointer)
    return Int(_size)
  }
  
  public subscript(index: Int) -> SIMD3<Double> {
    get {
      let _element = _openmm_index_get(pointer, index, OpenMM_Vec3Array_get)
      
      // Cannot assume this is aligned to 4 x 8 bytes, so read each element
      // separately. If this part becomes a bottleneck in the CPU code, we know
      // how to fix it.
      let _vector: OpenMM_Vec3 = _element.pointee
      return SIMD3(_vector.x, _vector.y, _vector.z)
    }
    set {
      let _vector = OpenMM_Vec3(x: newValue.x, y: newValue.y, z: newValue.z)
      OpenMM_Vec3Array_set(pointer, Int32(index), _vector)
    }
  }
}

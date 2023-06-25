//
//  OpenMM_System.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/25/23.
//

import COpenMM

public class OpenMM_State: OpenMM_Object {
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_State_destroy(pointer)
  }
  
  public var positions: OpenMM_Vec3Array {
    .init(_openmm_get(pointer, OpenMM_State_getPositions))
  }
  
  public var time: Double {
    _openmm_get(pointer, OpenMM_State_getTime)
  }
}

public class OpenMM_System: OpenMM_Object {
  public override init() {
    super.init(_openmm_create(OpenMM_System_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_System_destroy(pointer)
  }
  
  /// Transfer ownership of the `OpenMM_Force` to OpenMM before calling this.
  @discardableResult
  public func addForce(_ force: OpenMM_Force) -> Int {
    let index = OpenMM_System_addForce(pointer, force.pointer)
    return Int(index)
  }
  
  @discardableResult
  public func addParticle(mass: Double) -> Int {
    let index = OpenMM_System_addParticle(pointer, mass)
    return Int(index)
  }
}

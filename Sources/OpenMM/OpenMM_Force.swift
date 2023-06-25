//
//  OpenMM_Force.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/25/23.
//

import COpenMM

public class OpenMM_Force: OpenMM_Object {
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_Force_destroy(pointer)
  }
}

public class OpenMM_GBSAOBCForce: OpenMM_Force {
  public override init() {
    super.init(_openmm_create(OpenMM_GBSAOBCForce_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_GBSAOBCForce_destroy(pointer)
  }
}

public class OpenMM_NonbondedForce: OpenMM_Force {
  public override init() {
    super.init(_openmm_create(OpenMM_NonbondedForce_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_NonbondedForce_destroy(pointer)
  }
  
  @discardableResult
  public func addParticle(charge: Double, sigma: Double, epsilon: Double) -> Int {
    let index = OpenMM_NonbondedForce_addParticle(
      pointer, charge, sigma, epsilon)
    return Int(index)
  }
}

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
  
  @discardableResult
  public func addParticle(
    charge: Double, radius: Double, scalingFactor: Double
  ) -> Int {
    let index = OpenMM_GBSAOBCForce_addParticle(
      pointer, charge, radius, scalingFactor)
    return Int(index)
  }
  
  public var soluteDielectric: Double {
    get {
      _openmm_get(pointer, OpenMM_GBSAOBCForce_getSoluteDielectric)
    }
    set {
      OpenMM_GBSAOBCForce_setSoluteDielectric(pointer, newValue)
    }
  }
  
  public var solventDielectric: Double {
    get {
      _openmm_get(pointer, OpenMM_GBSAOBCForce_getSolventDielectric)
    }
    set {
      OpenMM_GBSAOBCForce_setSolventDielectric(pointer, newValue)
    }
  }
}

public class OpenMM_HarmonicAngleForce: OpenMM_Force {
  public override init() {
    super.init(_openmm_create(OpenMM_HarmonicAngleForce_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_HarmonicAngleForce_destroy(pointer)
  }
}

public class OpenMM_HarmonicBondForce: OpenMM_Force {
  public override init() {
    super.init(_openmm_create(OpenMM_HarmonicBondForce_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_HarmonicBondForce_destroy(pointer)
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

public class OpenMM_PeriodicTorsionForce: OpenMM_Force {
  public override init() {
    super.init(_openmm_create(OpenMM_PeriodicTorsionForce_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_PeriodicTorsionForce_destroy(pointer)
  }
}
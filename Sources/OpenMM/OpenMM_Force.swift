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

public class OpenMM_CustomAngleForce: OpenMM_Force {
  public init(energy: String) {
    super.init(_openmm_create(energy, OpenMM_CustomAngleForce_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_CustomAngleForce_destroy(pointer)
  }
  
  @discardableResult
  public func addAngle(
    particles: SIMD3<Int>, parameters: OpenMM_DoubleArray
  ) -> Int {
    let index = OpenMM_CustomAngleForce_addAngle(
      pointer, Int32(particles[0]), Int32(particles[1]),
      Int32(particles[2]), parameters.pointer)
    return Int(index)
  }
  
  @discardableResult
  public func addGlobalParameter(
    name: String, defaultValue: Double
  ) -> Int {
    let index = OpenMM_CustomAngleForce_addGlobalParameter(
      pointer, name, defaultValue)
    return Int(index)
  }
  
  @discardableResult
  public func addPerAngleParameter(
    name: String
  ) -> Int {
    let index = OpenMM_CustomAngleForce_addPerAngleParameter(
      pointer, name)
    return Int(index)
  }
}

public class OpenMM_CustomBondForce: OpenMM_Force {
  public init(energy: String) {
    super.init(_openmm_create(energy, OpenMM_CustomBondForce_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_CustomBondForce_destroy(pointer)
  }
  
  @discardableResult
  public func addBond(
    particles: SIMD2<Int>, parameters: OpenMM_DoubleArray
  ) -> Int {
    let index = OpenMM_CustomBondForce_addBond(
      pointer, Int32(particles[0]), Int32(particles[1]), parameters.pointer)
    return Int(index)
  }
  
  @discardableResult
  public func addGlobalParameter(
    name: String, defaultValue: Double
  ) -> Int {
    let index = OpenMM_CustomBondForce_addGlobalParameter(
      pointer, name, defaultValue)
    return Int(index)
  }
  
  @discardableResult
  public func addPerBondParameter(
    name: String
  ) -> Int {
    let index = OpenMM_CustomBondForce_addPerBondParameter(
      pointer, name)
    return Int(index)
  }
}

public class OpenMM_CustomCompoundBondForce: OpenMM_Force {
  public init(numParticles: Int, energy: String) {
    super.init(_openmm_create(
      Int32(numParticles), energy, OpenMM_CustomCompoundBondForce_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_CustomCompoundBondForce_destroy(pointer)
  }
  
  @discardableResult
  public func addBond(
    particles: OpenMM_IntArray, parameters: OpenMM_DoubleArray
  ) -> Int {
    let index = OpenMM_CustomCompoundBondForce_addBond(
      pointer, particles.pointer, parameters.pointer)
    return Int(index)
  }
  
  @discardableResult
  public func addGlobalParameter(
    name: String, defaultValue: Double
  ) -> Int {
    let index = OpenMM_CustomCompoundBondForce_addGlobalParameter(
      pointer, name, defaultValue)
    return Int(index)
  }
  
  @discardableResult
  public func addPerBondParameter(
    name: String
  ) -> Int {
    let index = OpenMM_CustomCompoundBondForce_addPerBondParameter(
      pointer, name)
    return Int(index)
  }
}

public class OpenMM_CustomNonbondedForce: OpenMM_Force {
  public init(energy: String) {
    super.init(_openmm_create(energy, OpenMM_CustomNonbondedForce_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_CustomNonbondedForce_destroy(pointer)
  }
  
  public func createExclusionsFromBonds(
    _ bonds: OpenMM_BondArray, bondCutoff: Int
  ) {
    OpenMM_CustomNonbondedForce_createExclusionsFromBonds(
      pointer, bonds.pointer, Int32(bondCutoff))
  }
  
  @discardableResult
  public func addGlobalParameter(
    name: String, defaultValue: Double
  ) -> Int {
    let index = OpenMM_CustomNonbondedForce_addGlobalParameter(
      pointer, name, defaultValue)
    return Int(index)
  }
  
  @discardableResult
  public func addParticle(
    parameters: OpenMM_DoubleArray
  ) -> Int {
    let index = OpenMM_CustomNonbondedForce_addParticle(
      pointer, parameters.pointer)
    return Int(index)
  }
  
  @discardableResult
  public func addPerParticleParameter(
    name: String
  ) -> Int {
    let index = OpenMM_CustomNonbondedForce_addPerParticleParameter(
      pointer, name)
    return Int(index)
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
  
  @discardableResult
  public func addAngle(
    particles: SIMD3<Int>, angle: Double, k: Double
  ) -> Int {
    let index = OpenMM_HarmonicAngleForce_addAngle(
      pointer, Int32(particles[0]), Int32(particles[1]),
      Int32(particles[2]), angle, k)
    return Int(index)
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
  
  @discardableResult
  public func addBond(
    particles: SIMD2<Int>, length: Double, k: Double
  ) -> Int {
    let index = OpenMM_HarmonicBondForce_addBond(
      pointer, Int32(particles[0]), Int32(particles[1]), length, k)
    return Int(index)
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
  public func addParticle(
    charge: Double, sigma: Double, epsilon: Double
  ) -> Int {
    let index = OpenMM_NonbondedForce_addParticle(
      pointer, charge, sigma, epsilon)
    return Int(index)
  }
  
  public func createExceptionsFromBonds(
    _ bonds: OpenMM_BondArray, coulomb14Scale: Double, lj14Scale: Double
  ) {
    OpenMM_NonbondedForce_createExceptionsFromBonds(
      pointer, bonds.pointer, coulomb14Scale, lj14Scale)
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
  
  @discardableResult
  public func addTorsion(
    particles: SIMD4<Int>, periodicity: Int, phase: Double, k: Double
  ) -> Int {
    let index = OpenMM_PeriodicTorsionForce_addTorsion(
      pointer, Int32(particles[0]), Int32(particles[1]), Int32(particles[2]),
      Int32(particles[3]), Int32(periodicity), phase, k)
    return Int(index)
  }
}

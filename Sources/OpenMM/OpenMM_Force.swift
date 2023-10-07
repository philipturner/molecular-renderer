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
  
  public var forceGroup: Int {
    get {
      Int(_openmm_get(pointer, OpenMM_Force_getForceGroup))
    }
    set {
      OpenMM_Force_setForceGroup(pointer, Int32(newValue))
    }
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

public class OpenMM_CustomHbondForce: OpenMM_Force {
  public struct NonbondedMethod: OptionSet {
    public var rawValue: UInt32
    
    @inlinable
    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }
    
    init(_ _openmm_type: OpenMM_CustomHbondForce_NonbondedMethod) {
      self.init(rawValue: UInt32(_openmm_type.rawValue))
    }
    
    public static let noCutoff: NonbondedMethod =
      .init(OpenMM_CustomHbondForce_NoCutoff)
    public static let cutoffNonPeriodic: NonbondedMethod =
      .init(OpenMM_CustomHbondForce_CutoffNonPeriodic)
    public static let cutoffPeriodic: NonbondedMethod =
      .init(OpenMM_CustomHbondForce_CutoffPeriodic)
  }
  
  public init(energy: String) {
    super.init(_openmm_create(energy, OpenMM_CustomHbondForce_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_CustomHbondForce_destroy(pointer)
  }
  
  @discardableResult
  public func addAcceptor(
    particles: SIMD2<Int>, parameters: OpenMM_DoubleArray
  ) -> Int {
    let index = OpenMM_CustomHbondForce_addAcceptor(
      pointer, Int32(particles[0]), Int32(particles[1]), Int32(particles[2]),
      parameters.pointer)
    return Int(index)
  }
  
  @discardableResult
  public func addDonor(
    particles: SIMD2<Int>, parameters: OpenMM_DoubleArray
  ) -> Int {
    let index = OpenMM_CustomHbondForce_addDonor(
      pointer, Int32(particles[0]), Int32(particles[1]), Int32(particles[2]),
      parameters.pointer)
    return Int(index)
  }
  
  @discardableResult
  public func addExclusion(
    donor: Int, acceptor: Int
  ) -> Int {
    let index = OpenMM_CustomHbondForce_addExclusion(
      pointer, Int32(donor), Int32(acceptor))
    return Int(index)
  }
  
  @discardableResult
  public func addGlobalParameter(
    name: String, defaultValue: Double
  ) -> Int {
    let index = OpenMM_CustomHbondForce_addGlobalParameter(
      pointer, name, defaultValue)
    return Int(index)
  }
  
  @discardableResult
  public func addPerAcceptorParameter(
    name: String
  ) -> Int {
    let index = OpenMM_CustomHbondForce_addPerAcceptorParameter(
      pointer, name)
    return Int(index)
  }
  
  @discardableResult
  public func addPerDonorParameter(
    name: String
  ) -> Int {
    let index = OpenMM_CustomHbondForce_addPerDonorParameter(
      pointer, name)
    return Int(index)
  }
  
  public var cutoffDistance: Double {
    get {
      _openmm_get(pointer, OpenMM_CustomHbondForce_getCutoffDistance)
    }
    set {
      OpenMM_CustomHbondForce_setCutoffDistance(pointer, newValue)
    }
  }
  
  public var nonbondedMethod: NonbondedMethod {
    get {
        let rawValue: UInt32 = UInt32(OpenMM_CustomHbondForce_getNonbondedMethod(pointer).rawValue)
        return NonbondedMethod(rawValue: rawValue)
    }
    set {
      let rawValue = OpenMM_CustomHbondForce_NonbondedMethod(
        rawValue: .init(newValue.rawValue))
      OpenMM_CustomHbondForce_setNonbondedMethod(pointer, rawValue)
    }
  }
}

public class OpenMM_CustomNonbondedForce: OpenMM_Force {
  public struct NonbondedMethod: OptionSet {
    public var rawValue: UInt32
    
    @inlinable
    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }
    
    init(_ _openmm_type: OpenMM_CustomNonbondedForce_NonbondedMethod) {
      self.init(rawValue: UInt32(_openmm_type.rawValue))
    }
    
    public static let noCutoff: NonbondedMethod =
      .init(OpenMM_CustomNonbondedForce_NoCutoff)
    public static let cutoffNonPeriodic: NonbondedMethod =
      .init(OpenMM_CustomNonbondedForce_CutoffNonPeriodic)
    public static let cutoffPeriodic: NonbondedMethod =
      .init(OpenMM_CustomNonbondedForce_CutoffPeriodic)
  }
  
  public init(energy: String) {
    super.init(_openmm_create(energy, OpenMM_CustomNonbondedForce_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_CustomNonbondedForce_destroy(pointer)
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
  
  public func createExclusionsFromBonds(
    _ bonds: OpenMM_BondArray, bondCutoff: Int
  ) {
    OpenMM_CustomNonbondedForce_createExclusionsFromBonds(
      pointer, bonds.pointer, Int32(bondCutoff))
  }
  
  public var cutoffDistance: Double {
    get {
      _openmm_get(pointer, OpenMM_CustomNonbondedForce_getCutoffDistance)
    }
    set {
      OpenMM_CustomNonbondedForce_setCutoffDistance(pointer, newValue)
    }
  }
  
  public var nonbondedMethod: NonbondedMethod {
    get {
        let rawValue: UInt32 = UInt32(OpenMM_CustomNonbondedForce_getNonbondedMethod(pointer).rawValue)
        return NonbondedMethod(rawValue: rawValue)
    }
    set {
      let rawValue = OpenMM_CustomNonbondedForce_NonbondedMethod(
        rawValue: .init(newValue.rawValue))
      OpenMM_CustomNonbondedForce_setNonbondedMethod(pointer, rawValue)
    }
  }
  
  public var switchingDistance: Double {
    get {
      _openmm_get(pointer, OpenMM_CustomNonbondedForce_getSwitchingDistance)
    }
    set {
      OpenMM_CustomNonbondedForce_setSwitchingDistance(pointer, newValue)
    }
  }
  
  public var useSwitchingFunction: Bool {
    get {
      let rawValue = _openmm_get(pointer, OpenMM_CustomNonbondedForce_getUseSwitchingFunction)
      return rawValue == OpenMM_True
    }
    set {
      let rawValue = newValue ? OpenMM_True : OpenMM_False
      OpenMM_CustomNonbondedForce_setUseSwitchingFunction(pointer, rawValue)
    }
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

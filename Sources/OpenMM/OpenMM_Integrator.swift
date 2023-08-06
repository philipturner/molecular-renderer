//
//  OpenMM_Integrator.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/25/23.
//

import COpenMM

public class OpenMM_Integrator: OpenMM_Object {
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_Integrator_destroy(pointer)
  }
  
  public var constraintTolerance: Double {
    get {
      _openmm_get(pointer, OpenMM_Integrator_getConstraintTolerance)
    }
    set {
      OpenMM_Integrator_setConstraintTolerance(pointer, newValue)
    }
  }
  
  public func step(_ steps: Int) {
    OpenMM_Integrator_step(pointer, Int32(steps))
  }
}

public class OpenMM_BrownianIntegrator: OpenMM_Integrator {
  public convenience init(
    temperature: Double, frictionCoeff: Double, stepSize: Double
  ) {
    self.init(_openmm_create(
      temperature, frictionCoeff, stepSize,
      OpenMM_BrownianIntegrator_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_BrownianIntegrator_destroy(pointer)
  }
}

public class OpenMM_CustomIntegrator: OpenMM_Integrator {
  public convenience init(stepSize: Double) {
    self.init(_openmm_create(stepSize, OpenMM_CustomIntegrator_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_CustomIntegrator_destroy(pointer)
  }
  
  @discardableResult
  public func addComputeGlobal(
    variable: String, expression: String
  ) -> Int {
    let index = OpenMM_CustomIntegrator_addComputeGlobal(
      pointer, variable, expression)
    return Int(index)
  }
  
  @discardableResult
  public func addComputePerDof(
    variable: String, expression: String
  ) -> Int {
    let index = OpenMM_CustomIntegrator_addComputePerDof(
      pointer, variable, expression)
    return Int(index)
  }
  
  @discardableResult
  public func addConstrainPositions() -> Int {
    let index = OpenMM_CustomIntegrator_addConstrainPositions(pointer)
    return Int(index)
  }
  
  @discardableResult
  public func addConstrainVelocities() -> Int {
    let index = OpenMM_CustomIntegrator_addConstrainVelocities(pointer)
    return Int(index)
  }
  
  @discardableResult
  public func addGlobalVariable(
    name: String, initialValue: Double
  ) -> Int {
    let index = OpenMM_CustomIntegrator_addGlobalVariable(
      pointer, name, initialValue)
    return Int(index)
  }
  
  @discardableResult
  public func addPerDofVariable(
    name: String, initialValue: Double
  ) -> Int {
    let index = OpenMM_CustomIntegrator_addPerDofVariable(
      pointer, name, initialValue)
    return Int(index)
  }
  
  @discardableResult
  public func addUpdateContextState() -> Int {
    let index = OpenMM_CustomIntegrator_addUpdateContextState(pointer)
    return Int(index)
  }
  
  @discardableResult
  public func beginIfBlock(condition: String) -> Int {
    let index = OpenMM_CustomIntegrator_beginIfBlock(pointer, condition)
    return Int(index)
  }
  
  public func endBlock() {
    OpenMM_CustomIntegrator_endBlock(pointer)
  }
}

public class OpenMM_LangevinMiddleIntegrator: OpenMM_Integrator {
  public convenience init(
    temperature: Double, frictionCoeff: Double, stepSize: Double
  ) {
    self.init(_openmm_create(
      temperature, frictionCoeff, stepSize,
      OpenMM_LangevinMiddleIntegrator_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_LangevinMiddleIntegrator_destroy(pointer)
  }
}

public class OpenMM_NoseHooverIntegrator: OpenMM_Integrator {
  public convenience init(stepSize: Double) {
    let pointer = OpenMM_NoseHooverIntegrator_create(stepSize)
    self.init(pointer)
    self.retain()
  }
  
  public convenience init(
    temperature: Double, collisionFrequency: Double, stepSize: Double,
    chainLength: Int = 3, numMTS: Int = 3, numYoshidaSuzuki: Int = 7
  ) {
    let pointer = OpenMM_NoseHooverIntegrator_create_2(
      temperature, collisionFrequency, stepSize,
      Int32(chainLength), Int32(numMTS), Int32(numYoshidaSuzuki))
    self.init(pointer)
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_NoseHooverIntegrator_destroy(pointer)
  }
}

public class OpenMM_VerletIntegrator: OpenMM_Integrator {
  public convenience init(stepSize: Double) {
    self.init(_openmm_create(stepSize, OpenMM_VerletIntegrator_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_VerletIntegrator_destroy(pointer)
  }
}

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
  
  public func step(_ steps: Int) {
    OpenMM_Integrator_step(pointer, Int32(steps))
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

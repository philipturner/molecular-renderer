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

public class OpenMM_VerletIntegrator: OpenMM_Integrator {
  public convenience init(stepSize: Double) {
    self.init(_openmm_create(stepSize, OpenMM_VerletIntegrator_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_VerletIntegrator_destroy(pointer)
  }
}

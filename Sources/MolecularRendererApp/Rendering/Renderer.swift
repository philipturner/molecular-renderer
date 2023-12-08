//
//  Renderer.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

import AppKit
import KeyCodes
import Metal
import MolecularRenderer
import OpenMM
import simd

import HDL
import MM4
import Numerics

class Renderer {
  unowned let coordinator: Coordinator
  unowned let eventTracker: EventTracker
  
  // Rendering resources.
  var renderSemaphore: DispatchSemaphore = .init(value: 3)
  var renderingEngine: MRRenderer!
  
  // Geometry providers.
  var atomProvider: MRAtomProvider!
  var styleProvider: MRAtomStyleProvider!
  var animationFrameID: Int = 0
  var gifSerializer: GIFSerializer!
  var serializer: Serializer!
  
  // Camera scripting settings.
  static let recycleSimulation: Bool = false
  static let productionRender: Bool = false
  static let programCamera: Bool = false
  
  init(coordinator: Coordinator) {
    self.coordinator = coordinator
    self.eventTracker = coordinator.eventTracker
    
    do {
      let descriptor = MRRendererDescriptor()
      descriptor.url = Bundle.main.url(
        forResource: "MolecularRendererGPU", withExtension: "metallib")!
      if Self.productionRender {
        descriptor.width = 720
        descriptor.height = 640
        descriptor.offline = true
      } else {
        descriptor.width = Int(ContentView.size)
        descriptor.height = Int(ContentView.size)
        descriptor.upscaleFactor = ContentView.upscaleFactor
      }
      
      self.renderingEngine = MRRenderer(descriptor: descriptor)
      self.gifSerializer = GIFSerializer(
        path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
      self.serializer = Serializer(
        renderer: self,
        path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
      self.styleProvider = NanoStuff()
      initOpenMM()
    }
    
    var diamondoid = adamantaneDiamondoid()
    self.atomProvider = ArrayAtomProvider(diamondoid.atoms)
    
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = diamondoid.atoms.map { $0.element }
    paramsDesc.bonds = diamondoid.bonds.map {
      SIMD2<UInt32>(truncatingIfNeeded: $0)
    }
    let params = try! MM4Parameters(descriptor: paramsDesc)
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.positions = diamondoid.atoms.map { $0.origin }
    rigidBodyDesc.parameters = params
    rigidBodyDesc.velocities = diamondoid.createVelocities()
    var rigidBody = MM4RigidBody(descriptor: rigidBodyDesc)
    
    let angularVelocity = Quaternion<Float>(angle: 1, axis: [
      0.70710678, 0.70710678, 0
    ])
    diamondoid.angularVelocity = angularVelocity
    rigidBody.angularVelocity = angularVelocity
    do {
      var differences: [SIMD3<Float>] = []
      for (lhs, rhs) in zip(diamondoid.createVelocities(), rigidBody.velocities) {
        differences.append(lhs - rhs)
      }
    }
    rigidBody.velocities.withUnsafeBufferPointer {
      rigidBody.setVelocities($0)
    }
    print("expected angular velocity:", angularVelocity)
    print("expected angular velocity:", angularVelocity.angle * angularVelocity.axis)
    
    // rigid body angular velocity: (0.87758255, 0.33900505, 0.33900505, 0.0)
    
    let repartitionedMasses = rigidBody.parameters.atoms.masses.map(Double.init)
    let statePositions = diamondoid.atoms.map { $0.origin }.map(SIMD3<Double>.init)
    let stateVelocities = diamondoid.createVelocities().map(SIMD3<Double>.init)
    
    var totalMass: Double = 0
    var totalMomentum: SIMD3<Double> = .zero
    var centerOfMass: SIMD3<Double> = .zero
    
    // Conserve mtoomentum after the velocities are randomly initialized.
    for atomID in diamondoid.atoms.indices {
      let mass = repartitionedMasses[atomID]
      let position = statePositions[atomID]
      let velocity = stateVelocities[atomID]
      totalMass += Double(mass)
      totalMomentum += mass * velocity
      centerOfMass += mass * position
    }
    centerOfMass /= totalMass
    
    // Should be SIMD3<Float>(1.3476824e-07, 1.3006077e-07, -0.03191334)
    //           SIMD3<Float>(1.3132467e-07, 1.277512e-07, -0.03190822)
    print("           center of mass:", centerOfMass)
    print("rigid body center of mass:", rigidBody.centerOfMass)
    
    // Conserve angular momentum along the three cardinal axes, therefore
    // conserving angular momentum along any possible axis.
    var totalAngularMomentum: SIMD3<Double> = .zero
    var totalMomentOfInertia: cross_platform_double3x3 = .init(diagonal: .zero)
    for atomID in diamondoid.atoms.indices {
      let mass = repartitionedMasses[atomID]
      let delta = statePositions[atomID] - centerOfMass
      let velocity = stateVelocities[atomID]
      
      // From Wikipedia:
      // https://en.wikipedia.org/wiki/Rigid_body_dynamics#Mass_properties
      //
      // I_R = m * (I (S^T S) - S S^T)
      // where S is the column vector R - R_cm
      let STS = cross_platform_dot(delta, delta)
      var momentOfInertia = cross_platform_double3x3(diagonal: .init(repeating: STS))
      momentOfInertia -= cross_platform_double3x3(rows: [
        SIMD3(delta.x * delta.x, delta.x * delta.y, delta.x * delta.z),
        SIMD3(delta.y * delta.x, delta.y * delta.y, delta.y * delta.z),
        SIMD3(delta.z * delta.x, delta.z * delta.y, delta.z * delta.z),
      ])
      momentOfInertia *= mass
      totalMomentOfInertia += momentOfInertia
      
      // From Wikipedia:
      // https://en.wikipedia.org/wiki/Rigid_body_dynamics#Linear_and_angular_momentum
      //
      // L = m * (R - R_cm) cross d/dt (R - R_cm)
      // assume R_cm is stationary
      // L = m * (R - R_cm) cross v
      let angularMomentum = mass * cross_platform_cross(delta, velocity)
      totalAngularMomentum += angularMomentum
    }
    let totalAngularVelocity = totalMomentOfInertia
      .inverse * totalAngularMomentum
    print("     total angular velocity:", totalAngularVelocity)
    print("rigid body angular velocity:", rigidBody.angularVelocity)
    
    // Next, query the linear velocity, see what happens when you mutate:
    // - center of mass
    // - linear velocity
    //
    // Inertia | Position | Velocity |
    // mass    | centerOfMass | linearVelocity |
    // momentOfInertia | rotate() | angularVelocity |
    
    // Next, call rotate(), which likely will face bugs in the custom quaternion
    // act implementation.
    
    
    // Before the code that computes moment of inertia above, rotate both objects. Confirm that both objects' moment of inertia become a different value, and the rigid body's moment is un-cached upon mutation.
    //
    // Should be different than: (SIMD3<Float>(19.959436, -0.04870774, -2.4214387e-07), SIMD3<Float>(-0.04870774, 19.959436, -2.9802322e-07), SIMD3<Float>(-2.4214387e-07, -2.9802322e-07, 24.405872))
    // And whatever the new value is, now that you have changed the position
    // and orientation:
    print("     total moment of inertia:", totalMomentOfInertia)
    print("rigid body moment of inertia:", rigidBody.momentOfInertia)
    
    // Next, see what happens when you add anchors, handles, and external forces.
    
    // Next, see what happens when you read/write energy, including the heuristic for heat capacity.
  }
}

//
//  Axle.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/23/24.
//

import Foundation
import HDL
import MM4
import Numerics

// Simulation code, for reference.
#if false
struct Axle: GenericPart {
  var rigidBody: MM4RigidBody
  
  init() {
    let lattice = Self.createLattice()
    let topology = Self.createTopology(lattice: lattice)
    rigidBody = Self.createRigidBody(topology: topology)
    
    // Set the center of mass to zero.
    rigidBody.centerOfMass = .zero
  }
  
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 8 * h + 8 * k + 12 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 4 * (h + k + l) }
        
        for degreeIndex in 0..<180 {
          let θ = Float(degreeIndex) * 2 * (Float.pi / 180)
          let r = Float(1.1) / 0.3567
          
          let x = r * Float.cos(θ)
          let y = r * Float.sin(θ)
          Convex {
            Origin { x * h + y * k }
            Plane { x * h + y * k }
          }
        }
        Replace { .empty }
      }
    }
  }
}

func createGeometry() -> [[MM4RigidBody]] {
  // Design an axle with the required radius, and test whether it retains its
  // kinetic energy for 30 revolutions at 30 GHz. Repeat this process with an
  // auto-generated housing structure.
  
  // MARK: - Initialize Parts
  
  var axle = Axle()
  axle.minimize(bulkAtomIDs: [])
  
  var rotaryPartDesc = RotaryPartDescriptor()
  rotaryPartDesc.cachePath =
  "/Users/philipturner/Documents/OpenMM/cache/RotaryPart.data"
  
  let rotaryPart = RotaryPart(descriptor: rotaryPartDesc)
  
  // MARK: - Run Simulation
  
  var simulation = GenericSimulation(rigidBodies: [
    axle.rigidBody, rotaryPart.rigidBody
  ])
  simulation.withForceField {
    $0.minimize(tolerance: 0.1)
  }
  simulation.setVelocitiesToTemperature(2 * 298)
  simulation.withForceField {
    $0.simulate(time: 2)
  }
  
  // Erase all net momenta.
  for rigidBodyID in simulation.rigidBodies.indices {
    var rigidBody = simulation.rigidBodies[rigidBodyID]
    rigidBody.angularMomentum = .zero
    rigidBody.linearMomentum = .zero
    simulation.rigidBodies[rigidBodyID] = rigidBody
  }
  
  // Set the axle's angular momentum.
  do {
    var rigidBody = simulation.rigidBodies[0]
    guard (rigidBody.principalAxes.2.z).magnitude > 0.99 else {
      fatalError("Principal axis was not aligned with the z-axis: \(rigidBody.principalAxes).")
    }
    
    let frequencyInGHz: Double = 30
    var ω = SIMD3<Double>(0, 0, frequencyInGHz * 0.001 * 2 * .pi)
    if rigidBody.principalAxes.2.z < 0 {
      ω.z = -ω.z
    }
    rigidBody.angularMomentum = ω * rigidBody.momentOfInertia
    simulation.rigidBodies[0] = rigidBody
  }
  
  var frames: [[MM4RigidBody]] = []
  print("frame: 0")
  frames.append(simulation.rigidBodies)
  
  for frameID in 1...600 {
    let timeStep: Double = 0.5
    simulation.withForceField {
      $0.simulate(time: timeStep)
    }
    
    // Fetch the kinetic energy.
    var kineticEnergy = simulation.forceField.energy.kinetic
    
    // Subtract the axle's kinetic energy.
    var axleEnergy: Double
    do {
      let rigidBody = simulation.rigidBodies[0]
      let I = rigidBody.momentOfInertia
      let L = rigidBody.angularMomentum
      let ω = L / I
      
      let K = 0.5 * (ω * I * ω).sum()
      kineticEnergy -= K
      axleEnergy = K
    }
    
    // Find the wheel's kinetic energy.
    var wheelEnergy: Double
    do {
      let rigidBody = simulation.rigidBodies[1]
      let I = rigidBody.momentOfInertia
      let L = rigidBody.angularMomentum
      let ω = L / I
      
      let K = 0.5 * (ω * I * ω).sum()
      kineticEnergy -= K
      wheelEnergy = K
    }
    
    // Compute the kinetic energy per atom.
    let atomCount = simulation.forceField.positions.count
    let energyPerAtom = kineticEnergy / Double(atomCount)
    
    // Report the frame's data.
    let time = Double(frameID) * timeStep
    print(
      "frame:", frameID, "|",
      String(format: "%.1f", time), "ps |",
      "temperature:", String(format: "%.2f", energyPerAtom), "zJ/atom |",
      "axle energy:", String(format: "%.1f", axleEnergy), "zJ |",
      "wheel energy:", String(format: "%.1f", wheelEnergy), "zJ")
    frames.append(simulation.rigidBodies)
  }
  
  return frames
}
#endif

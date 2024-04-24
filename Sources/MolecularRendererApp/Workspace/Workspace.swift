import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [[MM4RigidBody]] {
  // Design a system of two gears and two axles, in a stiff housing. Spin the
  // two gears in opposite directions. Determine how many cycles the kinetic
  // energy survives for, at various temperatures.
  
  // MARK: - Initialize Parts
  
  let carrier = Carrier()
  
  var rotaryPartDesc = RotaryPartDescriptor()
  rotaryPartDesc.cachePath = "/Users/philipturner/Documents/OpenMM/cache/RotaryPart.data"
  let rotaryPartBase = RotaryPart(descriptor: rotaryPartDesc)
  
  var rotaryPart1 = rotaryPartBase
  var rotaryPart2 = rotaryPartBase
  rotaryPart1.rigidBody.centerOfMass.x -= 7.625 * 0.3567
  rotaryPart2.rigidBody.centerOfMass.x += 7.625 * 0.3567
  rotaryPart2.rigidBody.rotate(angle: 0.07, axis: [0, 0, 1])
  
  var simulation = GenericSimulation(rigidBodies: [
    carrier.rigidBody,
    rotaryPart1.rigidBody,
    rotaryPart2.rigidBody,
  ])
  simulation.withForceField {
    print($0.energy.potential)
  }
  simulation.withForceField {
    $0.minimize(tolerance: 10)
  }
  simulation.withForceField {
    print($0.energy.potential)
  }
  simulation.setVelocitiesToTemperature(2 * 298)
  simulation.withForceField {
    $0.simulate(time: 2)
  }
  
  // MARK: - Run Simulation
  
  // Erase all net momenta.
  for rigidBodyID in simulation.rigidBodies.indices {
    var rigidBody = simulation.rigidBodies[rigidBodyID]
    rigidBody.angularMomentum = .zero
    rigidBody.linearMomentum = .zero
    simulation.rigidBodies[rigidBodyID] = rigidBody
  }
  
  // Set each rigid body's angular momentum.
  for rigidBodyID in simulation.rigidBodies.indices {
    // Load the rigid body.
    var rigidBody = simulation.rigidBodies[rigidBodyID]
    guard rigidBodyID > 0 else {
      continue
    }
    
    // Check the principal axis.
    guard (rigidBody.principalAxes.0.z).magnitude > 0.99 else {
      fatalError("Principal axis was not aligned with the z-axis: \(rigidBody.principalAxes).")
    }
    
    // Determine the angular velocity.
    let frequencyInGHz: Double = 15
    var ω = SIMD3<Double>(frequencyInGHz * 0.001 * 2 * .pi, 0, 0)
    if rigidBody.principalAxes.0.z < 0 {
      ω = -ω
    }
    
    // Reverse the angular velocity of the second wheel.
    if rigidBodyID % 2 == 0 {
      ω = -ω
    }
    
    // Set the angular momentum.
    rigidBody.angularMomentum = ω * rigidBody.momentOfInertia
    
    // Store the rigid body.
    simulation.rigidBodies[rigidBodyID] = rigidBody
  }
  
  // Record the frames.
  var frames: [[MM4RigidBody]] = []
  print("frame: 0")
  frames.append(simulation.rigidBodies)
  
  for frameID in 1...500 {
    let timeStep: Double = 1
    simulation.withForceField {
      $0.simulate(time: timeStep)
    }
    
    // Fetch the simulation kinetic energy.
    var thermalEnergy = simulation.forceField.energy.kinetic
    
    // Fetch each rigid body's kinetic energy.
    var kineticEnergies: [Double] = []
    for rigidBody in simulation.rigidBodies {
      let I = rigidBody.momentOfInertia
      let L = rigidBody.angularMomentum
      let ω = L / I
      
      let K = 0.5 * (ω * I * ω).sum()
      thermalEnergy -= K
      kineticEnergies.append(K)
    }
    
    // Compute the kinetic energy per atom.
    let atomCount = simulation.forceField.positions.count
    let energyPerAtom = thermalEnergy / Double(atomCount)
    
    // Report the frame's data.
    let time = Double(frameID) * timeStep
    print(
      "frame:", frameID, "|",
      String(format: "%.1f", time), "ps |",
      "temperature:", String(format: "%.2f", energyPerAtom), "zJ/atom |",
      String(format: "%.1f", kineticEnergies[0]), "zJ |",
      String(format: "%.1f", kineticEnergies[1]), "zJ |",
      String(format: "%.1f", kineticEnergies[2]), "zJ")
    frames.append(simulation.rigidBodies)
  }
  
  return frames
}

struct Carrier: GenericPart {
  var rigidBody: MM4RigidBody
  
  init() {
    let lattice = Self.createLattice()
    let topology = Self.createTopology(lattice: lattice)
    rigidBody = Self.createRigidBody(topology: topology)
    
    // Run an energy minimization.
    let bulkAtomIDs = Self.extractBulkAtomIDs(topology: topology)
    minimize(bulkAtomIDs: bulkAtomIDs)
    
    // Set the center of mass to zero.
    rigidBody.centerOfMass = .zero
  }
  
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 25 * h + 12 * k + 18 * l }
      Material { .elemental(.carbon) }
      
      func createAxle() {
        Convex {
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
        }
      }
      
      Volume {
        Convex {
          Origin { 24.25 * h }
          Plane  { h }
        }
        
        Origin { 6 * k }
        
        Concave {
          Concave {
            Origin { 4 * l }
            Plane { l }
          }
          Concave {
            Origin { 4.5 * h }
            createAxle()
          }
          Concave {
            Origin { 19.75 * h }
            createAxle()
          }
          Concave {
            Origin { 14 * l }
            Plane { -l }
          }
        }
        
        Replace { .empty }
      }
    }
  }
}

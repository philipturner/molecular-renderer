//
//  DriveSystemPartData.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/14/24.
//

import Foundation
import HDL
import MM4
import Numerics

protocol DriveSystemPart {
  var rigidBody: MM4RigidBody { get }
  var knobAtomIDs: [UInt32] { get }
}

struct DriveSystemPartPosition {
  var bodyCenter: SIMD3<Double> = .zero
  var bodyMass: Double = .zero
  var knobCenter: SIMD3<Double> = .zero
  var knobMass: Double = .zero
  
  init(source: DriveSystemPart) {
    let rigidBody = source.rigidBody
    let knobAtomIDSet = Set(source.knobAtomIDs)
    for atomID in rigidBody.parameters.atoms.indices {
      let mass = Double(rigidBody.parameters.atoms.masses[atomID])
      let position = SIMD3<Double>(rigidBody.positions[atomID])
      
      if knobAtomIDSet.contains(UInt32(atomID)) {
        knobCenter += mass * position
        knobMass += mass
      } else {
        bodyCenter += mass * position
        bodyMass += mass
      }
    }
    bodyCenter /= bodyMass
    knobCenter /= knobMass
  }
}

struct DriveSystemPartEnergy {
  var linearKinetic: Double
  var angularKinetic: Double
  var thermalKinetic: Double
  var temperature: Double
  
  var total: Double {
    linearKinetic +
    angularKinetic +
    thermalKinetic
  }
  
  init(rigidBody: MM4RigidBody) {
    // Find the total kinetic energy of all atoms combined.
    var totalEnergy: Double = .zero
    for atomID in rigidBody.parameters.atoms.indices {
      let mass = rigidBody.parameters.atoms.masses[atomID]
      let velocity = rigidBody.velocities[atomID]
      totalEnergy += Double(0.5 * mass * (velocity * velocity).sum())
    }
    
    // Decompose the energy into its principal components.
    let v = rigidBody.linearMomentum / rigidBody.mass
    let ω = rigidBody.angularMomentum / rigidBody.momentOfInertia
    linearKinetic = 0.5 * rigidBody.mass * (v * v).sum()
    angularKinetic = 0.5 * (ω * rigidBody.momentOfInertia * ω).sum()
    thermalKinetic = totalEnergy - linearKinetic - angularKinetic
    
    // E = 3/2 n kT
    // T = E / (3/2 n k)
    let n = Double(rigidBody.parameters.atoms.count)
    let boltzmannConstantInJ = 1.380649e-23
    let boltzmannConstantInZJ = boltzmannConstantInJ / 1e-21
    temperature = thermalKinetic / (1.5 * n * boltzmannConstantInZJ)
  }
  
  func display() {
    print("  - energy:")
    print("    - total:", String(format: "%.2f", total))
    print("    - linear kinetic:", String(format: "%.2f", linearKinetic))
    print("    - angular kinetic:", String(format: "%.2f", angularKinetic))
    print("    - thermal kinetic:", String(format: "%.2f", thermalKinetic))
    print("    - temperature:", String(format: "%.2f", temperature), "K")
  }
}

// Summary of the energy analysis.
struct DriveSystemEnergy {
  var potential: Double
  var kinetic: Double
  var total: Double { potential + kinetic }
  
  var organizedKinetic: Double
  var thermalKinetic: Double
  var temperature: Double
  
  init(forceField: MM4ForceField, rigidBodies: [MM4RigidBody]) {
    potential = forceField.energy.potential
    kinetic = forceField.energy.kinetic
    
    organizedKinetic = .zero
    thermalKinetic = .zero
    for rigidBody in rigidBodies {
      let energy = DriveSystemPartEnergy(rigidBody: rigidBody)
      organizedKinetic += energy.linearKinetic
      organizedKinetic += energy.angularKinetic
      thermalKinetic += energy.thermalKinetic
    }
    
    var atomCount: Int = .zero
    for rigidBody in rigidBodies {
      atomCount += rigidBody.parameters.atoms.count
    }
    
    // E = 3/2 n kT
    // T = E / (3/2 n k)
    let n = Double(atomCount)
    let boltzmannConstantInJ = 1.380649e-23
    let boltzmannConstantInZJ = boltzmannConstantInJ / 1e-21
    temperature = thermalKinetic / (1.5 * n * boltzmannConstantInZJ)
  }
  
  func display(initialSystemEnergy: Double?) {
    // Record the energy analysis from molecular dynamics.
    print("- energy:")
    print("  - total: \(String(format: "%.2f", total)) zJ", terminator: "")
    if let initialSystemEnergy {
      let drift = total - initialSystemEnergy
      print(" (drift: \(String(format: "%.2f", drift)))")
    } else {
      print()
    }
    print("  - potential:", String(format: "%.2f", potential))
    print("  - kinetic:", String(format: "%.2f", kinetic))
    
    // Record the kinetic energy reproduced from the rigid bodies.
    let rigidBodyKinetic = organizedKinetic + thermalKinetic
    print("  - kinetic:", String(format: "%.2f", rigidBodyKinetic), "(rigid body analysis)")
    print("    - organized kinetic:", String(format: "%.2f", organizedKinetic))
    print("    - thermal kinetic:", String(format: "%.2f", thermalKinetic))
    print("    - temperature:", String(format: "%.2f", temperature), "K")
  }
}

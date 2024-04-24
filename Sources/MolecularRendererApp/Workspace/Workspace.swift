import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  // Design a system of two gears and two axles, in a stiff housing. Spin the
  // two gears in opposite directions. Determine how many cycles the kinetic
  // energy survives for, at various temperatures.
  
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
    $0.minimize(tolerance: 0.1)
  }
  simulation.withForceField {
    print($0.energy.potential)
  }
  
  return simulation.rigidBodies
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

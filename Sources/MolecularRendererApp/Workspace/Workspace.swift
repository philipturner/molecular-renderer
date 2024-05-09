import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [[MM4RigidBody]] {
  var top = Top()
  top.rigidBody.centerOfMass = .zero
  
  let ω = SIMD3(0.1, 0.08, 0.05)
  
  // Fetch the eigenvalues of the moment of inertia.
  let I = top.rigidBody.momentOfInertia
  
  // Assign the angular momentum. The value is stored as the projection in the
  // rigid body's local reference frame.
  top.rigidBody.angularMomentum = I * ω
  
  // Rotate the rigid body for a series of timesteps.
  var rotationProgress: Double = .zero
  var output: [[MM4RigidBody]] = []
  output.append([top.rigidBody])
  for frameID in 1...10 {
    print()
    print("frame:", frameID)
    
    // Rotate around the rotation axis for 3.637 picoseconds. With the current
    // angular velocity of 0.1374, that should be 0.5 radians per timestep.
    do {
      let ω = top.rigidBody.angularMomentum / top.rigidBody.momentOfInertia
      let ωMagnitude = (ω * ω).sum().squareRoot()
      top.rigidBody.rotate(angle: ωMagnitude * 3.637)
      
      rotationProgress += ωMagnitude * 3.637
      print("The rigid body has rotated \(rotationProgress) radians.")
    }
    output.append([top.rigidBody])
  }
  
  // Stretch out the animation to 60 frames/timestep.
  output = output.flatMap { rigidBodies in
    Array(repeating: rigidBodies, count: 60)
  }
  return output
}

struct Top: GenericPart {
  var rigidBody: MM4RigidBody
  
  init() {
    let lattice = Self.createLattice()
    let topology = Self.createTopology(lattice: lattice)
    rigidBody = Self.createRigidBody(topology: topology)
    
    let bulkAtomIDs = Self.extractBulkAtomIDs(topology: topology)
    minimize(bulkAtomIDs: bulkAtomIDs)
  }
  
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 20 * h + 20 * k + 20 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 10 * h + 10 * l }
        
        // Create the bottom of the top.
        for angleID in 0..<180 {
          let angle = Float(2 * angleID) * (Float.pi / 180)
          let xValue = Float.cos(angle)
          let zValue = -Float.sin(angle)
          
          Convex {
            Plane { SIMD3(xValue, -1.5, zValue) }
          }
          Convex {
            Origin { 10 * SIMD3(xValue, 0, zValue) }
            Plane { SIMD3(xValue, 0, zValue) }
          }
        }
        
        // Create the handle of the top.
        for angleID in 0..<180 {
          let angle = Float(2 * angleID) * (Float.pi / 180)
          let xValue = Float.cos(angle)
          let zValue = -Float.sin(angle)
          
          Concave {
            Convex {
              Origin { 10 * k }
              Plane { k }
            }
            Convex {
              Origin { 3 * SIMD3(xValue, 0, zValue) }
              Plane { SIMD3(xValue, 0, zValue) }
            }
          }
        }
        
        Replace { .empty }
      }
    }
  }
}

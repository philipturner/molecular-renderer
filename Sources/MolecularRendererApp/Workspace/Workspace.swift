import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  var top = Top()
  
  // Define the initial angular velocity in rad/ps (1 rad/ps = 159 GHz).
  // ω = [0.1, 0.08, 0.05]
  // -  first principal axis: 15.9 GHz
  // - second principal axis: 8.0 GHz
  // -  third principal axis: 8.0 GHz
  //
  // Projection onto axis of rotation:
  // (ω * ω).sum().squareRoot() = 0.1374772708486752 rad/ps
  // - 21.86 GHz
  let ω = SIMD3(0.1, 0.08, 0.05)
  print((ω * ω).sum().squareRoot())
  
  // Fetch the eigenvalues of the moment of inertia.
  // I = [1.582e6, 1.311e6, 1.310e6]
  // -  first principal axis: 1.582e6 units
  // - second principal axis: 1.311e6 units
  // -  third principal axis: 1.310e6 units
  //
  // Eigenvectors (not fetched here):
  // -  first principal axis: [-0.0002,  0.9999,  0.0000]
  // - second principal axis: [ 0.7115,  0.0001, -0.7025]
  // -  third principal axis: [-0.7025, -0.0001, -0.7115]
  let I = top.rigidBody.momentOfInertia
  print(I)
  
  // Assign the angular momentum. The value is stored as the projection in the
  // rigid body's local reference frame:
  // top.rigidBody.angularMomentum = [158279, 104903, 65540]
  // -  first principal axis: 158279 units
  // - second principal axis: 65564 units
  // -  third principal axis: 65540 units
  top.rigidBody.angularMomentum = I * ω
  print(top.rigidBody.angularMomentum)
  
  // Projection onto the global reference frame:
  do {
    // Angular momentum.
    // worldL = [28557, 158270, -120364]
    // - projection onto x-axis: 28557 units
    // - projection onto y-axis: 158270 units
    // - projection onto z-axis: 120364 units
    let axes = top.rigidBody.principalAxes
    let localL = top.rigidBody.angularMomentum
    var worldL: SIMD3<Double> = .zero
    worldL += axes.0 * localL[0]
    worldL += axes.1 * localL[1]
    worldL += axes.2 * localL[2]
    print(worldL)
    
    // Angular velocity.
    // worldω = [0.0217, 0.0999, -0.0918]
    // - projection onto x-axis:  0.0217 rad/ps (3.5 GHz)
    // - projection onto y-axis:  0.0999 rad/ps (15.9 GHz)
    // - projection onto z-axis: -0.0918 rad/ps (3.5 GHz)
    // (worldω * worldω).sum().squareRoot() = 0.1374772708486752 rad/ps
    // - 21.86 GHz
    let localω = top.rigidBody.angularMomentum / top.rigidBody.momentOfInertia
    var worldω: SIMD3<Double> = .zero
    worldω += axes.0 * localω[0]
    worldω += axes.1 * localω[1]
    worldω += axes.2 * localω[2]
    print(worldω)
    print((worldω * worldω).sum().squareRoot())
  }
  
  // Rotate the rigid body for a series of timesteps.
  var rotationProgress: Double = .zero
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
    
    // Angular momentum.
    let axes = top.rigidBody.principalAxes
    let localL = top.rigidBody.angularMomentum
    var worldL: SIMD3<Double> = .zero
    worldL += axes.0 * localL[0]
    worldL += axes.1 * localL[1]
    worldL += axes.2 * localL[2]
    print("localL:", localL)
    print("worldL:", worldL)
    
    // Angular velocity.
    let localω = top.rigidBody.angularMomentum / top.rigidBody.momentOfInertia
    var worldω: SIMD3<Double> = .zero
    worldω += axes.0 * localω[0]
    worldω += axes.1 * localω[1]
    worldω += axes.2 * localω[2]
    print("localω:", localω)
    print("worldω:", worldω)
    print("(worldω * worldω).sum().squareRoot():", terminator: " ")
    print((worldω * worldω).sum().squareRoot())
    
    // Calculate the kinetic energy analytically.
    do {
      var kineticEnergy: Double = .zero
      
      let m = top.rigidBody.mass
      let p = top.rigidBody.linearMomentum
      let v = p / m
      kineticEnergy += 0.5 * (v * m * v).sum()
      
      let I = top.rigidBody.momentOfInertia
      let L = top.rigidBody.angularMomentum
      let ω = L / I
      kineticEnergy += 0.5 * (ω * I * ω).sum()
      
      print("kinetic energy from bulk properties:", kineticEnergy, "zJ")
    }
    
    // Calculate the kinetic energy numerically.
    do {
      var kineticEnergy: Double = .zero
      
      for atomID in top.rigidBody.parameters.atoms.indices {
        let mass = top.rigidBody.parameters.atoms.masses[atomID]
        let velocity = top.rigidBody.velocities[atomID]
        kineticEnergy += Double(0.5 * (velocity * mass * velocity).sum())
      }
      
      print("kinetic energy from atomic velocities:", kineticEnergy, "zJ")
    }
  }
  
  return [top.rigidBody]
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

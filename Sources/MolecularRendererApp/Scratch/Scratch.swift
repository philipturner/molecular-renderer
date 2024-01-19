// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [[Entity]] {
  var atoms: [Entity] = []
  var bonds: [SIMD2<UInt32>] = []
  var anchors: [Bool] = []
  var sceneParameters = {
    var descriptor = MM4ParametersDescriptor()
    descriptor.atomicNumbers = []
    descriptor.bonds = []
    return try! MM4Parameters(descriptor: descriptor)
  }()
  var rigidBodyParameters: [MM4Parameters] = []
  
  for x in 0..<4 {
    for z in 0..<4 {
      var descriptor = LogicHousingDescriptor()
      descriptor.grooves = [
        .lowerRodFrontBack,
        .upperRodLeftRight,
      ]
      
      if (z % 2 == 0) != (x % 2 == 0) {
        descriptor.grooves.insert(.lowerLeft)
        descriptor.grooves.insert(.lowerRight)
        descriptor.grooves.insert(.upperFront)
        descriptor.grooves.insert(.upperBack)
      } else {
        descriptor.grooves.insert(.lowerFront)
        descriptor.grooves.insert(.lowerBack)
        descriptor.grooves.insert(.upperLeft)
        descriptor.grooves.insert(.upperRight)
      }
      
      // Make the outer walls flush.
      if x == 0 {
        descriptor.grooves.remove(.lowerLeft)
        descriptor.grooves.remove(.upperLeft)
      }
      if x == 3 {
        descriptor.grooves.remove(.lowerRight)
        descriptor.grooves.remove(.upperRight)
      }
      if z == 0 {
        descriptor.grooves.remove(.lowerBack)
        descriptor.grooves.remove(.upperBack)
      }
      if z == 3 {
        descriptor.grooves.remove(.lowerFront)
        descriptor.grooves.remove(.upperFront)
      }
      
      let housing = LogicHousing(descriptor: descriptor)
      var shift = SIMD3<Float>(Float(x), 0, Float(z))
      shift *= 7.5 * Constant(.square) { .elemental(.carbon) }
      bonds += housing.topology.bonds.map {
        $0 &+ UInt32(truncatingIfNeeded: atoms.count)
      }
      atoms += housing.topology.atoms.map {
        var copy = $0
        copy.position += shift
        return copy
      }
      
      // Find which atoms are anchors.
      var paramsDesc = MM4ParametersDescriptor()
      paramsDesc.atomicNumbers = housing.topology.atoms.map(\.atomicNumber)
      paramsDesc.bonds = housing.topology.bonds
      let parameters = try! MM4Parameters(descriptor: paramsDesc)
      let atomsToAtomsMap = housing.topology.map(.atoms, to: .atoms)
      
    outer:
      for i in housing.topology.atoms.indices {
        guard parameters.atoms.centerTypes[i] == .quaternary else {
          anchors.append(false)
          continue outer
        }
        for neighbor in atomsToAtomsMap[i] {
          let centerType = parameters.atoms.centerTypes[Int(neighbor)]
          guard centerType == .quaternary else {
            anchors.append(false)
            continue outer
          }
          for neighbor in atomsToAtomsMap[Int(neighbor)] {
            let centerType = parameters.atoms.centerTypes[Int(neighbor)]
            guard centerType == .quaternary else {
              anchors.append(false)
              continue outer
            }
          }
        }
        anchors.append(true)
      }
      sceneParameters.append(contentsOf: parameters)
      rigidBodyParameters.append(parameters)
    }
  }
  
  // Energy-minimize the constrained system.
  var minimizationParameters = sceneParameters
  for i in atoms.indices where anchors[i] {
    minimizationParameters.atoms.masses[i] = 0
  }
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = minimizationParameters
  var forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = atoms.map(\.position)
  forceField.minimize()
  
  for i in forceField.positions.indices {
    atoms[i].position = forceField.positions[i]
  }
  
  var rigidBodies: [MM4RigidBody] = []
  var rigidBodyRanges: [Range<Int>] = []
  var rigidBodyCursor = 0
  for rigidBodyID in 0..<16 {
    let parameters = rigidBodyParameters[rigidBodyID]
    let range = rigidBodyCursor..<(rigidBodyCursor + parameters.atoms.count)
    rigidBodyRanges.append(range)
    
    var descriptor = MM4RigidBodyDescriptor()
    descriptor.parameters = parameters
    descriptor.positions = Array(forceField.positions[range])
    rigidBodies.append(try! MM4RigidBody(descriptor: descriptor))
    rigidBodyCursor += parameters.atoms.count
  }
  
  // Simulate the system with RBD. Commit to GitHub after finishing the
  // investigation, to archive the code before it's deleted. Then, start working
  // on programmable logic rod knobs + clocking mechanism.
  forceFieldDesc.parameters = sceneParameters
  forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = atoms.map(\.position)
  
  // Avoid the overhead of fetching this from OpenMM.
  func createKineticEnergy() -> Double {
    var energy: Double = .zero
    for rigidBody in rigidBodies {
      let mass = rigidBody.mass
      let v = rigidBody.linearMomentum / mass
      let I = rigidBody.momentOfInertia
      let w = rigidBody.angularMomentum / I
      energy += 0.5 * mass * (v * v).sum()
      energy += 0.5 * (w * I * w).sum()
    }
    return energy
  }
  
  var animation: [[Entity]] = [atoms]
  let positionsBuffer: UnsafeMutableBufferPointer<SIMD3<Float>> =
    .allocate(capacity: atoms.count)
  let entitiesBuffer: UnsafeMutableBufferPointer<Entity> =
    .allocate(capacity: atoms.count)
  entitiesBuffer.initialize(from: atoms)
  
  for frameID in 0...120 {
    let timeStep: Double = 0.080
    if frameID % 10 == 0 {
      let time = Double(frameID) * timeStep
      let temperature = createKineticEnergy() / Double(atoms.count)
      print("frame=\(frameID), time=\(String(format: "%.3f", time)) ps, temp=\(String(format: "%.3f", 1e3 * temperature)) yJ/atom")
    }
    if frameID == 0 {
      continue
    }
    
    // 3118.4 ms before updating the rigid bodies. Perhaps time how long is
    // spent on the rigid body part vs. the OpenMM part, when the rigid body
    // part is activated.
    //
    /*
     before optimizing
     - gpu_time=7428, cpu_time=867
     - gpu_time=7103, cpu_time=533
     - gpu_time=7152, cpu_time=719
     - gpu_time=7147, cpu_time=680
     - gpu_time=7367, cpu_time=587
     - gpu_time=7340, cpu_time=639
     - gpu_time=6974, cpu_time=534
     - gpu_time=7240, cpu_time=561
     - gpu_time=7128, cpu_time=628
     - gpu_time=7109, cpu_time=583
     - gpu_time=7050, cpu_time=560
     - gpu_time=7058, cpu_time=621
     */
    
    /*
     after optimizing
     - gpu_time=7278, cpu_time=303
     - gpu_time=7397, cpu_time=261
     - gpu_time=7070, cpu_time=258
     - gpu_time=6860, cpu_time=170
     - gpu_time=7194, cpu_time=171
     - gpu_time=6813, cpu_time=269
     - gpu_time=7034, cpu_time=176
     - gpu_time=7432, cpu_time=474
     - gpu_time=7174, cpu_time=193
     - gpu_time=6851, cpu_time=286
     - gpu_time=7219, cpu_time=228
     - gpu_time=7490, cpu_time=170
     */
    
    // Avoid the small overhead of fetching energy along with forces.
    var descriptor = MM4StateDescriptor()
    descriptor.forces = true
    
    let start = cross_platform_media_time()
    let state = forceField.state(descriptor: descriptor)
    let middle = cross_platform_media_time()
    let forces = state.forces!
    
    DispatchQueue.concurrentPerform(iterations: rigidBodies.count) { z in
      let i = z
      let range = rigidBodyRanges[z]
      do {
        rigidBodies[i].forces = Array(forces[range])
        rigidBodies[i].linearMomentum += timeStep * rigidBodies[i].netForce!
        rigidBodies[i].angularMomentum += timeStep * rigidBodies[i].netTorque!
        
        let I = rigidBodies[i].momentOfInertia
        let linearVelocity = rigidBodies[i].linearMomentum / rigidBodies[i].mass
        let angularVelocity = rigidBodies[i].angularMomentum / I
        let angularSpeed = (angularVelocity * angularVelocity).sum().squareRoot()
        rigidBodies[i].centerOfMass += timeStep * linearVelocity
        rigidBodies[i].rotate(angle: timeStep * angularSpeed)
        
        let positions = rigidBodies[i].positions
        var positionsCursor = 0
        for atomID in range {
          let position = positions[positionsCursor]
          positionsBuffer[atomID] = position
          entitiesBuffer[atomID].position = position
          positionsCursor += 1
        }
      }
    }
    forceField.positions = Array(positionsBuffer)
    animation.append(Array(entitiesBuffer))
    
    let end = cross_platform_media_time()
    let gpuMicroseconds = Int((middle - start) * 1e6)
    let cpuMicroseconds = Int((end - middle) * 1e6)
    if frameID % 10 == 0 {
      print(" - gpu_time=\(gpuMicroseconds), cpu_time=\(cpuMicroseconds)")
    }
  }
  positionsBuffer.deallocate()
  entitiesBuffer.deallocate()
  
  return animation
}

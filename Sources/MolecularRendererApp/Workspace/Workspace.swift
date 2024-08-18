import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [[Entity]] {
  let lattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 10 * h + 10 * h2k + 5 * l }
    Material { .checkerboard(.silicon, .carbon) }
  }
  
  // MARK: - Compile and minimize a lattice.
  
  var reconstruction = Reconstruction()
  reconstruction.material = .checkerboard(.silicon, .carbon)
  reconstruction.topology.insert(atoms: lattice.atoms)
  reconstruction.compile()
  var topology = reconstruction.topology
  
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = topology.bonds
  let parameters = try! MM4Parameters(descriptor: paramsDesc)
  
  print(parameters.nonbondedExceptions13.count)
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = topology.atoms.map(\.position)
  
  // Before the change:
  //
  // -550953.9609375
  // -550953.953125
  // -550953.9453125
  // -550953.9453125
  // -550953.9609375
  // -550953.96875
  // -550953.96875
  // -550953.953125
  // -550953.9453125
  // -550953.953125
  //
  // After the change:
  //
  // -550953.9609375
  // -550953.953125
  // -550953.9609375
  // -550953.9609375
  // -550953.9609375
  // -550953.953125
  // -550953.9609375
  // -550953.953125
  // -550953.9453125
  // -550953.953125
  print(forceField.energy.potential)
  
  forceField.minimize()
  
  // Before the change:
  //
  // -559768.0703125
  // -559768.078125
  // -559768.3828125
  // -559768.375
  // -559768.3828125
  // -559768.3671875
  // -559768.375
  // -559768.3671875
  // -559768.390625
  // -559768.3828125
  //
  // After the change:
  //
  // -559767.875
  // -559768.3671875
  // -559768.375
  // -559768.0703125
  // -559768.375
  // -559768.359375
  // -559768.0625
  // -559768.3671875
  // -559768.375
  // -559768.0625
  print(forceField.energy.potential)
  
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    let position = forceField.positions[atomID]
    atom.position = position
    topology.atoms[atomID] = atom
  }
  
  // MARK: - Set up a physics simulation.
  
  var rigidBodyDesc = MM4RigidBodyDescriptor()
  rigidBodyDesc.masses = topology.atoms.map {
    MM4Parameters.mass(atomicNumber: $0.atomicNumber)
  }
  rigidBodyDesc.positions = topology.atoms.map(\.position)
  var rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
  
  // angular velocity
  // - one revolution in 10 picoseconds
  // - r is about 3 nm
  // - v = 0.500 nm/ps
  //
  // v = wr
  // w = v / r = 0.167 rad/ps
  // 1 revolution in 37 picoseconds
  // validate that this hypothesis is correct with an MD simulation
  guard rigidBody.principalAxes.0.z.magnitude > 0.999 else {
    fatalError("z axis was not the first principal axis.")
  }
  let angularVelocity = SIMD3<Double>(0.167, 0, 0)
  rigidBody.angularMomentum = angularVelocity * rigidBody.momentOfInertia
  
  forceField.positions = rigidBody.positions
  forceField.velocities = rigidBody.velocities
  
  // MARK: - Record simulation frames for playback.
  
  var frames: [[Entity]] = []
  for frameID in 0...600 {
    let time = Double(frameID) * 0.010
    print("frame = \(frameID)", terminator: " | ")
    print("time = \(String(format: "%.2f", time))")
    
    if frameID > 0 {
      // 0.010 ps * 600
      // 6 ps total, 1.2 ps/s playback rate
      forceField.simulate(time: 0.010)
    }
    
    var frame: [Entity] = []
    for atomID in parameters.atoms.indices {
      let atomicNumber = parameters.atoms.atomicNumbers[atomID]
      let position = forceField.positions[atomID]
      let storage = SIMD4(position, Float(atomicNumber))
      frame.append(Entity(storage: storage))
    }
    frames.append(frame)
  }
  
  return frames
}

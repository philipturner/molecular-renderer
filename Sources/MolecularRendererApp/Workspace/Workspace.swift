import Foundation
import HDL
import MM4
import Numerics

#if false

// TODO: Changing the BVH construction procedure.
// - Clean up the BVH builder.
//   - De-obfuscate the atom buffers. [DONE]
//   - Remove the CPU code that wrote motion vectors to memory. [DONE]
//   - De-obfuscate the 'denseGridData' buffer.
// - Adapt the ray tracing code, so the reference grid has a fixed size.
//   - Clear a subregion matching the global BB every frame.
// - Remove the dependency on the global bounding box.
//
// TODO: Next, perform some optimizations.
// - Change the DDA, so the voxel address is computed every frame.
//   - Not a lot of compute cost, since integer multiplications become
//     bitshifts by log2(128).
// - Rearrange the reference grid in Morton order.
//   - Migrate the BVH construction first, resulting in twice the GPU work.
//   - Transform the new BVH into the old BVH.
//   - Integrate the transformed old BVH into the ray tracer.
//   - Migrate the ray tracer.

func createGeometry() -> [Atom] {
  // Benchmarked Systems
  //
  //              |                 |    C(100)   |   SiC(100)  |   Si(100)
  // ------------ | --------------- | ----------- | ----------- | -----------
  //  5 x  5 x  5 |     1,166 atoms |      7 nm^3 |     12 nm^3 |     23 nm^3
  // 10 x 10 x 10 |     8,631 atoms |     49 nm^3 |     89 nm^3 |    173 nm^3
  // 20 x 20 x 20 |    66,461 atoms |    377 nm^3 |    689 nm^3 |  1,331 nm^3
  // 30 x 30 x 30 |   221,491 atoms |  1,257 nm^3 |  2,295 nm^3 |  4,435 nm^3
  // 40 x 40 x 40 |   521,721 atoms |  2,960 nm^3 |  5,405 nm^3 | 10,447 nm^3
  // 50 x 50 x 50 | 1,015,151 atoms |  5,759 nm^3 | 10,517 nm^3 | 20,327 nm^3
  // 60 x 60 x 60 | 1,749,781 atoms |  9,927 nm^3 | 18,128 nm^3 | 35,038 nm^3
  // 70 x 70 x 70 | 2,773,611 atoms | 15,735 nm^3 | 28,735 nm^3 | 55,539 nm^3
  // 80 x 80 x 80 | 4,134,641 atoms |
  // 90 x 90 x 90 | 5,880,871 atoms |
  
  // Diamond
  //
  //              | Cell Size | Prep.  | Copy   | Geom.  | Render
  // ------------ | --------- | ------ | ------ | ------ | ------
  //  5 x  5 x  5 |   0.25 nm |     22 |      2 |     79 |   2018
  // 10 x 10 x 10 |   0.25 nm |    119 |      9 |     91 |   2633
  // 20 x 20 x 20 |   0.25 nm |    709 |     46 |    265 |   1781
  // 30 x 30 x 30 |   0.25 nm |    358 |     68 |    742 |   2700
  // 40 x 40 x 40 |   0.25 nm |    474 |    207 |   1474 |   2589
  // 50 x 50 x 50 |   0.25 nm |    743 |    344 |   2513 |   2301
  // 60 x 60 x 60 |   0.50 nm |   1080 |    580 |   2939 |   4093
  // 70 x 70 x 70 |   0.50 nm |   1538 |    923 |   3550 |   2944
  
  // Silicon Carbide
  //
  //              | Cell Size | Prep.  | Copy   | Geom.  | Render
  // ------------ | --------- | ------ | ------ | ------ | ------
  //  5 x  5 x  5 |   0.25 nm |     45 |      5 |     89 |   1984
  // 10 x 10 x 10 |   0.25 nm |    129 |      9 |    108 |   2428
  // 20 x 20 x 20 |   0.25 nm |    693 |     48 |    342 |   1739
  // 30 x 30 x 30 |   0.25 nm |    432 |     87 |    911 |   2389
  // 40 x 40 x 40 |   0.25 nm |    471 |    210 |   1773 |   2034
  // 50 x 50 x 50 |   0.25 nm |    754 |    356 |   2711 |   1942
  // 60 x 60 x 60 |   0.50 nm |   1146 |    577 |   2986 |   3577
  // 70 x 70 x 70 |   0.50 nm |   1625 |    908 |   3263 |   2501
  
  // Silicon
  //
  //              | Cell Size | Prep.  | Copy   | Geom.  | Render
  // ------------ | --------- | ------ | ------ | ------ | ------
  //  5 x  5 x  5 |   0.25 nm |     27 |      2 |     88 |   2060
  // 10 x 10 x 10 |   0.25 nm |    118 |      8 |    116 |   2494
  // 20 x 20 x 20 |   0.25 nm |    724 |     48 |    355 |   1932
  // 30 x 30 x 30 |   0.25 nm |    340 |     78 |    868 |   1726
  // 40 x 40 x 40 |   0.25 nm |    462 |    193 |   1900 |   1970
  // 50 x 50 x 50 |   0.25 nm |    731 |    330 |   3289 |   1938
  // 60 x 60 x 60 |   0.50 nm |   1057 |    565 |   3055 |   3678
  // 70 x 70 x 70 |   0.50 nm |   1541 |    917 |   3626 |   2523
  
  // Maximum Atom Count
  //
  //          | 256 atoms/voxel |  64 atoms/voxel | GPU reduction |
  // -------- | --------------- | --------------- | ------------- |
  //   C(100) |       1,664,096 |       6,697,971 |
  // SiC(100) |       1,423,913 |       5,687,546 |
  //  Si(100) |       1,208,030 |       4,784,221 |
  
  // Diamond (Compact Global BB)
  //
  //              | Prep.  | Copy   | Geom.  | Render | FPS
  // ------------ | ------ | ------ | ------ | ------ | ---
  //  5 x  5 x  5 |     39 |      4 |     89 |   2089 | 120
  // 10 x 10 x 10 |    142 |     10 |     94 |   2418 | 120
  // 20 x 20 x 20 |    513 |     46 |    321 |   2754 | 120
  // 30 x 30 x 30 |    495 |     88 |    777 |   2665 | 120
  // 40 x 40 x 40 |    483 |    205 |   1773 |   2181 | 120
  // 50 x 50 x 50 |    726 |    362 |   2553 |   1762 | 120
  // 60 x 60 x 60 |   1091 |    581 |   4739 |   2070 |  65
  // 70 x 70 x 70 |   1567 |    943 |   6318 |   1891 |  42
  // 80 x 80 x 80 |   2262 |   1361 |   9974 |   2158 |  31
  // 90 x 90 x 90 |   3163 |   1981 |  12936 |   2059 |  22
  
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 40 * (h + k + l) }
    Material { .elemental(.carbon) }
  }
  
  var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
  var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
  for atom in lattice.atoms {
    let position = atom.position
    minimum.replace(with: position, where: position .< minimum)
    maximum.replace(with: position, where: position .> maximum)
  }
  
  // Translate the lattice's atoms.
  var output: [Atom] = []
  for atomID in lattice.atoms.indices {
    var atom = lattice.atoms[atomID]
    var position = atom.position
    
    // Make the structure appear in front of the viewer.
    position.z -= maximum.z
    
    // Make the structure appear at the midpoint along its Y axis.
    position.y -= maximum.y / 2
    
    // Make the structure appear slightly to the right.
    position.x += 0.50
    
    atom.position = position
    output.append(atom)
  }
  
  return output
}

#else

// Test that animation functionality is working correctly.

func createGeometry() -> [[Atom]] {
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
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = topology.atoms.map(\.position)
  forceField.minimize()
  
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
  
  var frames: [[Atom]] = []
  for frameID in 0...300 {
    let time = Double(frameID) * 0.010
    print("frame = \(frameID)", terminator: " | ")
    print("time = \(String(format: "%.2f", time))")
    
    if frameID > 0 {
      // 0.010 ps * 600
      // 6 ps total, 1.2 ps/s playback rate
      forceField.simulate(time: 0.010)
    }
    
    var frame: [Atom] = []
    for atomID in parameters.atoms.indices {
      let atomicNumber = parameters.atoms.atomicNumbers[atomID]
      let position = forceField.positions[atomID]
      let atom = Atom(position: position, atomicNumber: atomicNumber)
      frame.append(atom)
    }
    frames.append(frame)
  }
  
  return frames
}

#endif

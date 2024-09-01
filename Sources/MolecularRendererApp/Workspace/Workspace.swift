import Foundation
import HDL
import MM4
import Numerics

// Making the code easier to modify.
// - Clean up the BVH builder.
//   - De-obfuscate the atom buffers. [DONE]
//   - Remove the CPU code that wrote motion vectors to memory. [DONE]
//   - De-obfuscate the 'denseGridData' buffer. [DONE]
//   - De-obfuscate the encoding of the old BVH building. [DONE]
// - De-obfuscate the frame report. [DONE]
// - De-obfuscate the resetting of the upscaler. [DONE]
//
// Changing the BVH construction procedure.
// - Offload the BB computation to the GPU.
//   - Make everything except computation of Int32 BB be GPU-driven. [DONE]
//   - Offload the BB reduction to the GPU, with a form almost exactly equal
//     to the current CPU kernel.
//     - Get feedback about whether it works (first pass). [DONE]
//     - Get feedback about whether it works (second pass). [DONE]
//       - Check both the diamond cube and the SiC MD simulation.
//     - Substitute the CPU value with the GPU value. [DONE]
//       - Check both the diamond cube and the SiC MD simulation.
//   - Delete the CPU code for reducing the bounding box. [DONE]
//
// Additional refactoring.
// - Group each pass's pipelines into a data structure. [DONE]
// - Overhaul the second kernel of the small cells pass. [DONE]
//
// Get the large-cell sorting working at all.
// - Get a head start on the first component of this pass.
//   - Use device atomics to find number of atoms in each large voxel. [DONE]
//   - Also allocate small cell references, in a single pass. [DONE]
//   - Try reducing divergence in the loop. [DONE]
//   - Use threadgroup memory to store relative offsets. [DONE]
//     - Detect and fix bank conflicts. [DONE]
//     - Determine whether 16-bit values in TG memory are faster. [DONE]
//     - Halve the device memory bandwidth. [DONE]
// - Run a parallel reduction across the large voxel grid. [DONE]
//   - Ensure the reference counts are summed correctly (+1). [DONE]
//   - Fuse the bounding box computation. [DONE]
//   - Optimizations:
//     - Reduce register pressure. [DONE]
//     - Skip computations or atomics for unoccupied voxels. [DONE]
//   - Generate indirect dispatch arguments in the "build large" pass. [DONE]
//   - Delete the bounding box kernels from the "prepare" pass. [DONE]
// - Store references to original atoms in the large voxels' lists.
//   - Delete the final kernel of the "prepare" pass. [DONE]
//   - Store the per-cell offsets. [DONE]
//   - Check the correctness of the per-cell offsets before writing atom
//     references (if possible). [DONE]
//   - Abstract away the code for iterating over large cell footprint. [DONE]
//     - Factored out part of it, specifically anything with control flow.
//     - It appears lower-effort to leave anything else duplicated.
//   - Check the correctness of written atom references. Use them as the source
//     of the small-cell atoms kernels. This means the ray tracer will
//     intersect some atoms twice. [DONE]
//
// Prepare the small-cell sorting for threadgroup atomics.
// - Swap the order of the small-cell-metadata and small-cell-counter buffers,
//   so the former is always the atomically incremented one. [DONE]
// - Change the indirect dispatch to 4x4x4, one cell per thread. [DONE]
// - Expand the small-counter metadata with ~4x duplication. [DONE]
//   - Revert this change. [DONE]
// - Try reducing divergence in the loops over small cells. [DONE]
// - Try storing the small-cell relative offsets to memory. [DONE]
//
// Write the kernel with threadgroup atomics.
// - Make the kernels iterate over the atoms within a threadgroup. [DONE]
// - Use threadgroup atomics to accumulate reference counts, but write the
//   counters to device memory afterward. [DONE]
// - Change the reduction over small cells to be scoped over 8x8x8. [DONE]
// - Fuse the first atoms kernel with memory clearing. [DONE]
// - Fuse the first atoms kernel with reduction over voxels. [DONE]
// - Fuse the first atoms kernel with the second atoms kernel. [DONE]
//
// Removing complexity from the fused kernel.
// - Optimize away the unnecessary transfers to device memory. [DONE]
//   - Remove the memory allocation for small-cell counters. [DONE]
// - Reduce the compute cost of cube-sphere testing. [DONE]
// - Remove the cross-GPU reduction, as the previous pass already compacted
//   the small atom references. [DONE]
//
// Preparing for 16-bit references.
// - Add a null terminator to the reference lists.
//   - Locate the place where the null terminator would be written. [DONE]
//   - Locate the place where the null terminator would be allocated. [DONE]
//   - Implement the null terminator. [DONE]
// - Remove the count from the cell metadata.
//   - Add a guard to the traversal function, so it exits anyway after 64
//     iterations. [DONE]
//   - Test integrity of rendering with the count ignored. [DONE]
//   - Remove the count and reformat the metadata. [DONE]
// - Write the converted atoms into a second buffer, whose length equals the
//   large reference count. Write during the large cells pass, so it doesn't
//   interfere with the benchmark of the small cells pass.
//   - Write the previous atoms while writing the converted atoms. This avoids
//     the complexity of pointer redirection, for the time being. [DONE]
//     - Accomplished this by writing motion vectors instead. [DONE]
//     - Compress the motion vectors to half precision. We can use a more
//       advanced format like rgb9e5 or rgb10 at a later date. [DONE]
//   - Write to a second, duplicate memory allocation. [DONE]
//     - Redirect the small-atom references, switch memory allocations. [DONE]
//     - Delete the old memory allocations.
// - Load the large voxel's metadata in the ray tracer.
//   - Subtract the large voxel's start from each small reference.
//
// Optimizing the new BVH.
// - Revisit the large-cell sorting pass, if the computation time is not
//   dwarfed by the small-cell sorting.
//   - Optimizing the "store relative offset" path by halving bandwidth cost.
//     - If this is faster than two-pass atomics would be, abort the idea.
//     - If this is faster than single-pass atomics would be, abort the idea.
//   - Sorting in two passes with atomics.
//   - Sorting in a single pass with atomics.
//     - Set up all of the memory allocations.
//     - Debug the failure modes of page allocation.
//     - Look for an atomics contention bottleneck.
// - Rearrange the cell metadata in Morton order.
//   - Create a second, 8-bit memory allocation that marks which small voxels
//     are occupied.
//   - Modify the DDA to traverse 8-bit cell metadata.
//   - Rearrange the 32-bit cell metadata in Morton order.
//   - Compact the 32-bit cell metadata, based on the <1/8 of large voxels
//     that are occupied.
// - Reduce the memory and bandwidth costs.
//   - Fuse the bounding box computation with the reduction across large cells.
//   - Shift to local, per-large sector reference lists (16-bit).
//   - Fuse multiple per-atom kernels, resulting in atom conversion only when
//     writing into the new reference list.
//     - (1) Revisit the large BVH construction, store both refs and atom data.
//   - With these optimizations, the limit of ~5 million atoms might be lifted.
//     A new limit of ~8 million atoms should be enforced, and the user can
//     decrease the limit to save memory.

#if false

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
  //   C(100) |       1,664,096 |       6,697,971 |    ~8,100,000 |
  // SiC(100) |       1,423,913 |       5,687,546 |    ~6,900,000 |
  //  Si(100) |       1,208,030 |       4,784,221 |    ~4,900,000 |
  
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

#endif

#if true

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

#if false

// Higher resolution means we can resolve much larger scenes. There is
// motivation to support atom counts far exceeding 4 million.
func createGeometry() -> [Atom] {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 100 * h + 100 * k + 8 * l }
    Material { .elemental(.silicon) }
  }
  
  var reconstruction = Reconstruction()
  reconstruction.material = .elemental(.silicon)
  reconstruction.topology.insert(atoms: lattice.atoms)
  reconstruction.compile()
  var topology = reconstruction.topology
  
  // Shift 50 nm toward negative Z.
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    atom.position += SIMD3(-30, -30, -60)
    topology.atoms[atomID] = atom
  }
  
  return topology.atoms
}
#endif

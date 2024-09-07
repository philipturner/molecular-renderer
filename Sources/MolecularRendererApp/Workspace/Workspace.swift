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
//     - Delete the old memory allocations. [DONE]
// - Load the large voxel's metadata in the ray tracer. [DONE]
//   - Subtract the large voxel's start from each small reference. [DONE]
//
// Preparing for 16-bit atoms.
// - Store the atomic number with the motion vectors. [DONE]
// - Remove the atomic number tag from the "converted" format. [DONE]
// - Compute the large voxel's lower corner during ray tracing. [DONE]
// - Subtract the large voxel's lower corner from the atom position. [DONE]
//
// Sparsifying the BVH.
// - Minimize the bandwidth cost of reading the large cells' counters during
//   BVH construction. [DONE]
//   - Write to a buffer of marks during the very first kernel, ensure it
//     doesn't harm performance. [DONE]
//   - Change the "return early" clause during the kernel over large cells, so
//     it reads from the marks. [DONE]
// - Rearrange the cell metadata.
//   - Merge the atom count with the small-cell offset.
//     - Make the small-cell ref. offsets relative to their corresponding
//       large-cell offset. [DONE]
//       - Add/subtract one to start off. [DONE]
//       - Fuse the offset with the count, in a 32-bit word. [DONE]
//       - Remove the addition/subtraction of one, as the count now
//         indicates whether the small voxel is occupied. [DONE]
//       - Remove the guard from the ray tracing loop. [DONE]
//     - Remove null termination from the reference list. [DONE]
//     - Remove null termination from as many other places as possible. [DONE]
//   - Test the optimization to sphere-cell tests before making more changes
//     that will affect performance. [DONE]
//     - Take five samples of the existing kernel's performance in Google
//       Sheets. Record the following for each sample: [DONE]
//       - Instructions issued
//       - Latency
//       - Divergence
//       - Line-by-line % for the sphere-cell test part.
//     - Change the CPU-side code, to clamp radii to [0.001, 0.249]. [DONE]
//   - Write the small cells' metadata at the compacted large voxel offsets,
//     in Morton order. [DONE]
//   - Switch to reading compacted data. [DONE]
//     - Bind the compacted metadata to the render kernel. [DONE]
//     - Fetch the large voxel's metadata during DDA traversal. [DONE]
//     - Read from an offset specified with large voxel metadata. [DONE]
//   - Delete the dense small-cell metadata. [DONE]
//     - Remove the buffer bindings from the render kernel. [DONE]
//     - Stop writing to it in the fused kernel. [DONE]
//   - Change the indirect dispatch for the fused kernel, so threadgroups
//     are only launched for occupied voxels. [DONE]
//     - Add a buffer of threadgroup IDs for occupied large voxels. [DONE]
//     - Make the dispatch 1D instead of 3D. [DONE]
//
// Implementing sparse ray tracing.
// - Remove the dependency on the global bounding box.
//   - Set the global bounding box to [-64, 64], overriding the reduced
//     value. [DONE]
//   - Ensure rendering still happens with reasonable performance. [DONE]
//     - Performance is not acceptable for real-time viewing (3 ms -> 11 ms),
//       but we'll investigate the issue when refactoring the DDA.
//     - Found the increase was more like (6 ms -> 11 ms), and we already had
//       6 ms for the most concerning scenes (which are not exposed to open
//       void or world boundaries).
//   - Eliminate the bounding box reduction. [DONE]
// - Refactor the DDA, making it easier to modify. [DONE]
//   - Reduce the number of state variables. [DONE]
//   - Remove the optimization that skips empty voxels. This is obfuscating
//     some inner mechanics of DDA traversal. [DONE]
//   - Is real-time rendering still possible? [DONE]
// - Start with a very expensive two-level DDA. [DONE]
// - Split into two separate traversal functions. [DONE]
//   - Re-encapsulate the sphere-cell intersection, but this time taking the
//     arguments for an entire voxel. [DONE]
//   - Give the functions different top-level names. [DONE]
//   - Remove 'isAORay' from the intersection parameters. [DONE]
// - Make a compacted list of large-voxel metadata, so smaller references can
//   be stored in threadgroup memory.
//   - Replace 'compactedLargeCellIDs' with this metadata. [DONE]
//   - Simplify the small-cells pass of BVH construction accordingly. [DONE]
//   - Bind the compacted large-cell metadata to the render kernel. [DONE]
//   - Modify the existing algorithm for compressing cell addresses. [DONE]
//   - Test for correctness and performance changes. [DONE]
// - Try speculative searching of the BVH.
//   - Buffer up the next few small cells. [DONE]
//   - Revert to the traversal method from before this change. [DONE]
//   - Buffer up the next few large cells in a separate DDA.
//     - The large DDA repeatedly calls 'nextLargeBorder'.
//     - Save each subsequently found large voxel in the memory tape.
//     - Each large voxel is iterated over in a loop. All of its small voxels
//       are tested before moving to the next one.
//     - The small DDA properly handles bounds of the 2 nm large voxel.
//  - Optimize the large DDA iterations.
//  - Reduce divergence of the small DDA iterations.
//    - A new small DDA is reinitialized on the fly.
//    - The small DDA loop halts when it runs out of large voxels to test.
//    - Attempt to reduce the load imbalance of divergent halting.
// - Re-implement the bounding box reduction, to decrease the number of
//   far-away cells traversed for primary rays.
//   - Properly handle the edge case where the user falls outside of the
//     world grid. [DONE]
//   - Re-implement the bounding box reduction.
//   - Find a good way to bind the bounding box to the render kernel.
//   - Measure a performance improvement.

#if true

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
    Bounds { 60 * (h + k + l) }
    Material { .elemental(.carbon) }
    
    Volume {
      Concave {
        Convex {
          Origin { 5 * h }
          Plane { h }
        }
        Convex {
          Origin { 5 * k }
          Plane { k }
        }
        Convex {
          Origin { 5 * l }
          Plane { l }
        }
      }
      Replace { .empty }
    }
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

#if false

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

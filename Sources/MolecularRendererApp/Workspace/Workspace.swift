import Foundation
import HDL
import MM4
import Numerics

// First, remove all of the different modes. Clean up the code from
// previous profiling experiments. Make the voxel size being 0.25 nm
// something hard-coded throughout the codebase. [DONE]
//
// Then, proceed with changing how the global bounding box is handled. [DONE]
//
// Preparing for GPU offloading:
// - Refactor the API for MRAtomStyle.
//   - Remove the checkerboard texture and flags. [DONE]
//   - Accept styles as an array. [DONE]
//   - Change all public API initializers to have FP32 arguments.
// - Refactor the API for entering atoms.
//   - Remove MRAtom from the public API, replace with SIMD4<Float>.
//   - Can we convert to MRAtom while memcpy'ing into the GPU buffer? How does
//     that compare to the memory bandwidth limit?
//   - Replace the MRAtomProvider API with something else.
// - Prepare a GPU kernel for the reduction.
//   - Add a new MRFrameReport section for GPU preprocessing. [DONE]
//   - Convert atom styles from FP32 to FP16 on the GPU, removing the compiler
//     error regarding x86_64.
//   - Convert from SIMD4<Float> to MRAtom on the GPU.
// - Allocate a fixed amount of memory for the grid.
//   - Allow the GPU to return early, resulting in a black screen.
//   - Make the GPU return early when the reference count is too high.
//   - Make the GPU return early when the cell count is too high.
// - Reduce the global bounding box on the GPU.

func createGeometry() -> [Entity] {
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
    Bounds { 10 * (h + k + l) }
    Material { .checkerboard(.silicon, .carbon) }
  }
  
  var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
  var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
  for atom in lattice.atoms {
    let position = atom.position
    minimum.replace(with: position, where: position .< minimum)
    maximum.replace(with: position, where: position .> maximum)
  }
  
  // Translate the lattice's atoms.
  var output: [Entity] = []
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

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  
  // Benchmarked geometries:
  //
  //              |                 |    C(100)   |   SiC(100)  |   Si(100)
  // ------------ | --------------- | ----------- | ----------- | -----------
  //  5 x  5 x  5 |     1,166 atoms |      7 nm^3 |     12 nm^3 |     23 nm^3
  //  7 x  7 x  7 |     3,060 atoms |     17 nm^3 |     32 nm^3 |     61 nm^3
  // 10 x 10 x 10 |     8,631 atoms |     49 nm^3 |     89 nm^3 |    173 nm^3
  // 15 x 15 x 15 |    28,396 atoms |    161 nm^3 |    294 nm^3 |    569 nm^3
  // 20 x 20 x 20 |    66,461 atoms |    377 nm^3 |    689 nm^3 |  1,331 nm^3
  // 25 x 25 x 25 |   128,826 atoms |    731 nm^3 |  1,335 nm^3 |  2,580 nm^3
  // 30 x 30 x 30 |   221,491 atoms |  1,257 nm^3 |  2,295 nm^3 |  4,435 nm^3
  // 35 x 35 x 35 |   350,456 atoms |  1,988 nm^3 |  3,631 nm^3 |  7,018 nm^3
  // 40 x 40 x 40 |   521,721 atoms |  2,960 nm^3 |  5,405 nm^3 | 10,447 nm^3
  // 45 x 45 x 45 |   741,286 atoms |  4,205 nm^3 |  7,680 nm^3 | 14,843 nm^3
  // 50 x 50 x 50 | 1,015,151 atoms |  5,759 nm^3 | 10,517 nm^3 | 20,327 nm^3
  // 55 x 55 x 55 | 1,349,316 atoms |  7,655 nm^3 | 13,979 nm^3 | 27,019 nm^3
  // 60 x 60 x 60 | 1,749,781 atoms |  9,927 nm^3 | 18,128 nm^3 | 35,038 nm^3
  
  // ## Latencies per frame (in microseconds):
  //
  // Diamond, 0.25 nm
  //
  //  5 x  5 x  5 |
  //  7 x  7 x  7 |
  // 10 x 10 x 10 |
  // 15 x 15 x 15 |
  // 20 x 20 x 20 |
  // 25 x 25 x 25 |
  // 30 x 30 x 30 |
  // 35 x 35 x 35 |
  // 40 x 40 x 40 |
  // 45 x 45 x 45 |
  // 50 x 50 x 50 |
  // 55 x 55 x 55 |
  // 60 x 60 x 60 |
  
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 5 * (h + k + l) }
    Material { .elemental(.carbon) }
  }
  print(lattice.atoms.count)
  print()
  
  // Print the volume of the lattice, for various materials.
  let materials: [MaterialType] = [
    .elemental(.carbon),
    .checkerboard(.silicon, .carbon),
    .elemental(.silicon)
  ]
  print("", terminator: " ")
  for materialID in materials.indices {
    let material = materials[materialID]
    
    let latticeConstant = Constant(.square) { material }
    let unitCellVolume = latticeConstant * latticeConstant * latticeConstant
    let atomDensity = 8 / unitCellVolume
    let volume = Float(lattice.atoms.count) / atomDensity
    
    // Use commas to show the number of decimal places.
    var truncatedVolume = Int(volume.rounded(.toNearestOrEven))
    var output = ""
    while truncatedVolume > 0 {
      // Take the remainder with one thousand.
      var segment = "\(truncatedVolume % 1000)"
      truncatedVolume /= 1000
      
      // Fill in zeroes.
      if truncatedVolume > 0 {
        while segment.count < 3 {
          segment = "0" + segment
        }
      }
      
      // Prepend to the output.
      if output.count > 0 {
        output = segment + "," + output
      } else {
        output = segment + " nm^3"
      }
    }
    
    // Pad to a uniform spacing.
    while output.count < 11 {
      output = " \(output)"
    }
    
    print(output, terminator: (materialID == 2) ? "\n" : " | ")
  }
  exit(0)
  
  return lattice.atoms
}

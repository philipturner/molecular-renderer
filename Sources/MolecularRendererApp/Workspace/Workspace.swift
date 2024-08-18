import Foundation
import HDL
import MM4
import Numerics

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
  
  // Diamond
  //
  //              | Cell Size |
  // ------------ | --------- |
  //  5 x  5 x  5 |
  // 10 x 10 x 10 |
  // 20 x 20 x 20 |
  // 30 x 30 x 30 |
  // 40 x 40 x 40 |
  // 50 x 50 x 50 |
  // 60 x 60 x 60 |
  // 70 x 70 x 70 |
  
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 70 * (h + k + l) }
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
  
  if true {
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
  }
  
  return output
}

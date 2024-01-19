// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  // Design a rod that connects to the actuator.
  let logicRodLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 20 * h + 2 * h2k + 4 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Convex {
        Origin { 1.9 * l }
        Plane { l }
      }
      Concave {
        Origin { 15 * h }
        Plane { h }
        Origin { 1.5 * h2k }
        Plane { h2k }
      }
      Replace { .empty }
    }
  }
  
  let binder = LogicHousingBinder()
  
  var output: [Entity] = []
  output += binder.topology.atoms.map {
    var copy = $0
    copy.position += 0.3567 * SIMD3(5, 8.5, 0)
    copy.position.z += 0.3567 * 3.5
    return copy
  }
  output += logicRodLattice.atoms.map {
    var copy = $0
    copy.position += 0.3567 * SIMD3(3, 2.5, 3.0)
    copy.position.z += 0.030
    copy.position.y -= 0.050
    return copy
  }
  output += logicRodLattice.atoms.map {
    var copy = $0
    copy.position += 0.3567 * SIMD3(3, 2.5, 3.0)
    copy.position.z += 0.030
    copy.position.y -= 0.050
    
    copy.position.z += 0.3567 * 7.5
    return copy
  }
  
  for yShift in 0..<2 {
    let logicHousing1 = LogicHousing(parity: false)
    output += logicHousing1.topology.atoms.map {
      var copy = $0
      copy.position = SIMD3(copy.position.z, copy.position.y, copy.position.x)
      copy.position.x += 0.3567 * 11
      copy.position.y += 0.3567 * 10.5 * Float(yShift)
      return copy
    }
    
    let logicHousing2 = LogicHousing(parity: true)
    output += logicHousing2.topology.atoms.map {
      var copy = $0
      copy.position.z += 0.3567 * 7.5
      copy.position.x += 0.3567 * 11
      copy.position.y += 0.3567 * 10.5 * Float(yShift)
      return copy
    }
  }
  return output
}

// Design the geometry for holding the housing units in-place from the
// outside.
struct LogicHousingBinder {
  var topology = Topology()
  
  init() {
    compilationPass0()
    // future compilation passes create grooves additively
  }
  
  mutating func compilationPass0() {
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 6 * h + 4 * k + 9 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Convex {
          Origin { 3.5 * k }
          Plane { k }
        }
        Convex {
          Origin { 5.5 * h }
          Plane { h }
        }
        Convex {
          Origin { 8.5 * l }
          Plane { l }
        }
        Replace { .empty }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
}

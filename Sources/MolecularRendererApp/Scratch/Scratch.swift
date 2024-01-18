// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [[Entity]] {
  let logicHousing = LogicHousing()
  var logicRod = LogicRod()
  for i in logicRod.topology.atoms.indices {
    var position = logicRod.topology.atoms[i].position
    position = SIMD3(position.z, position.y, position.x)
    position += 0.3567 * SIMD3(3.0, 2.5, -3)
    position.x += 0.030
    position.y -= 0.050
    logicRod.topology.atoms[i].position = position
  }
  var logicRod2 = logicRod
  for i in logicRod2.topology.atoms.indices {
    var position = logicRod2.topology.atoms[i].position
    position = SIMD3(position.z, position.y, position.x)
    position.y = 0.3567 * 10 - position.y
    logicRod2.topology.atoms[i].position = position
  }
  
  for i in logicRod.topology.atoms.indices {
    var position = logicRod.topology.atoms[i].position
    position += 0.3567 * SIMD3(0, 0, -3)
    logicRod.topology.atoms[i].position = position
  }
  
  var topologies = [
    logicHousing.topology,
    logicRod.topology,
    logicRod2.topology
  ]
//  return [topologies.flatMap(\.atoms)]
  var topologyRanges: [Range<Int>] = []
  var topologyCursor: Int = 0
  
  var parameters: MM4Parameters?
  for topology in topologies {
    var descriptor = MM4ParametersDescriptor()
    descriptor.atomicNumbers = topology.atoms.map(\.atomicNumber)
    descriptor.bonds = topology.bonds
    let params = try! MM4Parameters(descriptor: descriptor)
    
    if parameters == nil {
      parameters = params
    } else {
      parameters!.append(contentsOf: params)
    }
    
    let atomStart = topologyCursor
    topologyCursor += topology.atoms.count
    let atomEnd = topologyCursor
    topologyRanges.append(atomStart..<atomEnd)
  }
  
  var descriptor = MM4ForceFieldDescriptor()
  descriptor.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: descriptor)
  forceField.positions = topologies.flatMap { $0.atoms.map(\.position) }
  forceField.minimize()
  
  var externalForces = forceField.positions.map { $0 * 0 }
  for i in topologyRanges[1] {
    externalForces[i] = SIMD3(0, 0, 1)
  }
  forceField.externalForces = externalForces
  
  var animation: [[Entity]] = []
  for frameID in 0...120 {
    forceField.simulate(time: 0.100)
    
    for topologyID in topologies.indices {
      let positions = Array(forceField.positions[topologyRanges[topologyID]])
      for i in topologies[topologyID].atoms.indices {
        topologies[topologyID].atoms[i].position = positions[i]
      }
    }
    animation.append(topologies.flatMap(\.atoms))
  }
  
  return animation
}

struct LogicHousing {
  var topology = Topology()
  
  init() {
    createLattice()
    passivateSurfaces()
  }
  
  // The housing may need to be built out of SiC or GeC, if the atom spacings
  // are a poor multiple of vdW radius. This could also decrease compute cost,
  // especially if the housing is anchored in place.
  mutating func createLattice() {
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 8 * h + 10 * k + 8 * l }
      Material { .elemental(.carbon) }
      
      // Cut a hole for the rod to sit inside.
      func cutGroove(direction: SIMD3<Float>) {
        Concave {
          Origin { 2 * (direction + k) }
          
          var loopDirections: [SIMD3<Float>] = []
          loopDirections.append(direction)
          loopDirections.append(k)
          loopDirections.append(-direction)
          loopDirections.append(-k)
          
          for i in 0..<4 {
            Convex {
              Origin { loopDirections[i] * 2 }
              if i == 1 {
                Origin { 0.25 * k }
              }
              Plane { -loopDirections[i] }
            }
            Convex {
              let current = loopDirections[i]
              let next = loopDirections[(i + 1) % 4]
              Origin { (current + next) * 2 }
              Origin { (current + next) * -0.25 }
              if i == 0 || i == 1 {
                Origin { 0.25 * k }
              }
              Plane { -(current + next) }
            }
          }
        }
      }
      
      Volume {
        Convex {
          Origin { 2 * h + 1.5 * k }
          cutGroove(direction: h)
        }
        Convex {
          Origin { 2 * l + 4.25 * k }
          cutGroove(direction: l)
        }
        
        Replace { .empty }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  mutating func passivateSurfaces() {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.carbon)
    reconstruction.topology = topology
    reconstruction.removePathologicalAtoms()
    reconstruction.createBulkAtomBonds()
    reconstruction.createHydrogenSites()
    reconstruction.resolveCollisions()
    reconstruction.createHydrogenBonds()
    topology = reconstruction.topology
    topology.sort()
  }
}

// A fundmental component of a computer.
// - May need customizable length or customizable sequence of knobs.
// - Should be extensible to future variants with vdW connectors to a clock.
struct LogicRod {
  var topology = Topology()
  
  init() {
    createRod()
    passivateSurfaces()
  }
  
  // Find a static rod thickness that's optimal for the entire system. Then,
  // make the rod length variable.
  mutating func createRod() {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 20 * h + 2 * h2k + 4 * l }
      Material { .elemental(.carbon) }
      
      func cutGroove() {
        Concave {
          Convex {
            Plane { h }
          }
          Convex {
            Origin { 1.5 * h2k }
            Plane { h2k }
          }
          Convex {
            Origin { 6 * h }
            Plane { -h }
          }
        }
      }
      
      Volume {
        Convex {
          Origin { 1.9 * l }
          Plane { l }
        }
        Convex {
          Origin { -4 * h }
          cutGroove()
        }
        Convex {
          Origin { 7 * h }
          cutGroove()
        }
        Convex {
          Origin { 18 * h }
          cutGroove()
        }
        Replace { .empty }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  mutating func passivateSurfaces() {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.carbon)
    reconstruction.topology = topology
    reconstruction.removePathologicalAtoms()
    reconstruction.createBulkAtomBonds()
    reconstruction.createHydrogenSites()
    reconstruction.resolveCollisions()
    reconstruction.createHydrogenBonds()
    topology = reconstruction.topology
    topology.sort()
  }
}

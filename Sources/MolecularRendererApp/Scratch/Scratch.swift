// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [[Entity]] {
  #if false
  let logicRod = LogicRod()
  return [logicRod.topology.atoms]
  #endif
  
  #if false
  let logicHousing = LogicHousing()
  var logicRod = LogicRod()
  for i in logicRod.topology.atoms.indices {
    var position = logicRod.topology.atoms[i].position
    position = SIMD3(position.z, position.y, position.x)
    position += 0.3567 * SIMD3(2.5, 2.5, -1)
    logicRod.topology.atoms[i].position = position
  }
  return [logicHousing.topology.atoms + logicRod.topology.atoms]
  #endif
  
  #if true
  let logicHousing = LogicHousing()
  let masterLogicRod = LogicRod()
  
  var logicRods: [LogicRod] = []
  for logicRodID in 0..<4 {
    var logicRod = masterLogicRod
    let latticeConstant = Constant(.square) { .elemental(.carbon) }
    for i in logicRod.topology.atoms.indices {
      var position = logicRod.topology.atoms[i].position
      position = SIMD3(position.z, position.y, position.x)
      position.x += 0.030
      
      position += latticeConstant * SIMD3(2.5, 2.5, -1)
      position.x += latticeConstant * Float(logicRodID % 2) * 5.5
      if logicRodID == 1 {
        position.z += latticeConstant * 3
      }
      if logicRodID >= 2 {
        position.y += latticeConstant * 3
        position = SIMD3(position.z, position.y, position.x)
      }
      logicRod.topology.atoms[i].position = position
    }
    logicRods.append(logicRod)
  }
  
  let sceneTopologies = [logicHousing.topology] + logicRods.map(\.topology)
//  return [sceneTopologies.flatMap(\.atoms)]
  #endif
  
  #if true
  var parameters: MM4Parameters?
  var positions: [SIMD3<Float>] = []
  var forces: [SIMD3<Float>] = []
  for topology in sceneTopologies {
    var descriptor = MM4ParametersDescriptor()
    descriptor.atomicNumbers = topology.atoms.map(\.atomicNumber)
    descriptor.bonds = topology.bonds
    let params = try! MM4Parameters(descriptor: descriptor)
    
    if parameters == nil {
      parameters = params
    } else {
      parameters!.append(contentsOf: params)
    }
    positions += topology.atoms.map(\.position)
    for _ in topology.atoms.indices {
      forces.append(.zero)
    }
  }
  
  do {
    let atomStart = logicHousing
      .topology.atoms.count + masterLogicRod.topology.atoms.count
    let atomCount = logicRods[1].topology.atoms.filter {
      $0.position.z > 5
    }.count
    let forcePerAtom = Float(1000) / Float(atomCount)
    for atomID in logicRods[1].topology.atoms.indices {
      let atom = logicRods[1].topology.atoms[atomID]
      if atom.position.z > 5 {
        forces[atomStart + atomID] = SIMD3(0, 0, -forcePerAtom)
      }
    }
  }
  
  var descriptor = MM4ForceFieldDescriptor()
  descriptor.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: descriptor)
  forceField.positions = positions
  forceField.minimize()
  
  forceField.externalForces = forces
  
  var animation: [[Entity]] = []
  func takeSnapshot() {
    var frame: [Entity] = []
    for (i, position) in forceField.positions.enumerated() {
      let z = parameters!.atoms.atomicNumbers[i]
      frame.append(Entity(storage: SIMD4(position, Float(z))))
    }
    animation.append(frame)
  }
  takeSnapshot()
  
  for frameID in 0..<120 {
    if frameID % 10 == 0 {
      print("frame=\(frameID)")
    }
    forceField.simulate(time: 0.100)
    takeSnapshot()
  }
  
  return animation
  #endif
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
      Bounds { 13 * h + 10 * k + 13 * l }
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
              Plane { -loopDirections[i] }
            }
            Convex {
              let current = loopDirections[i]
              let next = loopDirections[(i + 1) % 4]
              Origin { (current + next) * 2 }
              Origin { (current + next) * -0.25 }
              Plane { -(current + next) }
            }
          }
        }
      }
      
      Volume {
        Convex {
          Origin { 1.5 * (h + k) }
          for i in 0..<2 {
            Convex {
              Origin { 5.5 * Float(i) * h }
              cutGroove(direction: h)
            }
          }
        }
        Convex {
          Origin { 12.5 * h }
          Plane { h }
        }
        
        Convex {
          Origin { 1.5 * l + 4.5 * k }
          for i in 0..<2 {
            Convex {
              Origin { 5.5 * Float(i) * l }
              cutGroove(direction: l)
            }
          }
        }
        Convex {
          Origin { 12.5 * l }
          Plane { l }
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
//    let lattice = Lattice<Cubic> { h, k, l in
//      Bounds { 2 * h + 2 * k + 15 * l }
//      Material { .elemental(.carbon) }
//      
//      Volume {
//        Convex {
//          Origin { 14.5 * l }
//          Plane { l }
//        }
//        
//        Replace { .empty }
//      }
//    }
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 20 * h + 2 * h2k + 4 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Convex {
          Origin { 1.9 * l }
          Plane { l }
        }
        Convex {
          Origin { 1.5 * h2k }
          Plane { h2k }
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

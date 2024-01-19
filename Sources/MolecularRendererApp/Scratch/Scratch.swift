// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [[Entity]] {
  let logicHousing = LogicHousing(parity: false)
  var logicHousing2 = LogicHousing(parity: true)
  for i in logicHousing2.topology.atoms.indices {
    var position = logicHousing2.topology.atoms[i].position
    position = SIMD3(position.z, position.y, position.x)
    position.x += 0.3567 * 7.5
    logicHousing2.topology.atoms[i].position = position
  }
  
  var logicRod = LogicRod(length: 20)
  for i in logicRod.topology.atoms.indices {
    var position = logicRod.topology.atoms[i].position
    position = SIMD3(position.z, position.y, position.x)
    position += 0.3567 * SIMD3(3.0, 2.5, -3)
    position.x += 0.030
    position.y -= 0.050
    logicRod.topology.atoms[i].position = position
  }
  var logicRod2 = LogicRod(length: 30)
  for i in logicRod2.topology.atoms.indices {
    var position = logicRod2.topology.atoms[i].position
    position = SIMD3(position.z, position.y, position.x)
    position += 0.3567 * SIMD3(3.0, 2.5, -3)
    position.x += 0.030
    position.y -= 0.050
    
    position = SIMD3(position.z, position.y, position.x)
    position.y = 0.3567 * 10 - position.y
    logicRod2.topology.atoms[i].position = position
  }
  var logicRod3 = logicRod
  for i in logicRod3.topology.atoms.indices {
    var position = logicRod3.topology.atoms[i].position
    position.x += 0.3567 * 7.5
    logicRod3.topology.atoms[i].position = position
  }
  
  var topologies = [
    logicHousing.topology,
    logicHousing2.topology,
    logicRod.topology,
    logicRod2.topology,
    logicRod3.topology
  ]
  var topologyRanges: [Range<Int>] = []
  var topologyCursor: Int = 0
//  return [topologies.flatMap(\.atoms)]
  
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
  
  var animation: [[Entity]] = []
  for frameID in 0..<180 {
    print("frame=\(frameID)")
    forceField.simulate(time: 0.100)
    
    if frameID == 10 {
      var externalForces = forceField.positions.map { $0 * 0 }
      for i in topologyRanges[3] {
        let perAtomForce = 100_000 / Float(logicRod2.topology.atoms.count)
        externalForces[i] = SIMD3(perAtomForce, 0, 0)
      }
      forceField.externalForces = externalForces
    }
    if frameID == 35 {
      var externalForces = forceField.positions.map { $0 * 0 }
      for i in topologyRanges[3] {
        let perAtomForce = -1_000_000 / Float(logicRod2.topology.atoms.count)
        externalForces[i] = SIMD3(perAtomForce, 0, 0)
      }
      forceField.externalForces = externalForces
    }
    if frameID >= 47 {
      forceField.velocities = forceField.positions.map { $0 * 0 }
      forceField.externalForces = forceField.positions.map { $0 * 0 }
      if frameID % 10 == 0 {
        forceField.minimize(maxIterations: 30)
      }
    }
    
    var frame: [Entity] = []
    for topologyID in topologies.indices {
      let topology = topologies[topologyID]
      let range = topologyRanges[topologyID]
      let positions = Array(forceField.positions[range])
      for i in positions.indices {
        let storage = SIMD4(positions[i], topology.atoms[i].storage.w)
        frame.append(Entity(storage: storage))
      }
    }
    animation.append(frame)
  }
  return animation
}

struct LogicHousing {
  var topology = Topology()
  
  init(parity: Bool) {
    createLattice(parity: parity)
    passivateSurfaces()
  }
  
  mutating func createLattice(parity: Bool) {
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
          let direction = parity ? l : h
          Origin { 2 * direction + 1.5 * k }
          cutGroove(direction: direction)
        }
        Convex {
          let direction = parity ? h : l
          Origin { 2 * direction + 4.25 * k }
          cutGroove(direction: direction)
        }
        
        Convex {
          Concave {
            Origin { 1 * h }
            Plane { -h }
            Origin { 5.5 * k }
            Origin { 0.25 * (-h - k) }
            Plane { -h - k }
          }
          Concave {
            Origin { 7 * h }
            Plane { h }
            Origin { 5.5 * k }
            Origin { 0.25 * (h - k) }
            Plane { h - k }
          }
          
          Concave {
            Origin { 1 * l }
            Plane { -l }
            Origin { 4.5 * k }
            Origin { 0.25 * (-l + k) }
            Plane { -l + k }
          }
          Concave {
            Origin { 7 * l }
            Plane { l }
            Origin { 4.5 * k }
            Origin { 0.25 * (l + k) }
            Plane { l + k }
          }
        }
        
        Convex {
          if parity {
            Origin { 0.5 * k }
            Plane { -k }
          } else {
            Origin { 9.5 * k }
            Plane { k }
          }
        }
        
        Origin { 4 * h + 4 * l }
        let directions = [h, l, -h, -l]
        for direction in directions {
          Convex {
            Origin { 3.5 * direction }
            Plane { direction }
          }
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
  
  init(length: Int) {
    createRod(length: length)
    passivateSurfaces()
  }
  
  // Find a static rod thickness that's optimal for the entire system. Then,
  // make the rod length variable.
  mutating func createRod(length: Int) {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { Float(length) * h + 2 * h2k + 4 * l }
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

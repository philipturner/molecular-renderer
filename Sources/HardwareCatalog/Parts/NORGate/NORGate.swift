//
//  NORGate.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 11/4/23.
//

import Foundation
import HDL
import MolecularRenderer
import QuaternionModule

// Previously RippleCounter2
struct LogicalNORGate1 {
  var provider: any MRAtomProvider
  var openmmProvider: OpenMM_AtomProvider?
  
  init(rod1True: Bool, rod2True: Bool) {
    provider = ArrayAtomProvider([
      MRAtom(origin: .zero, element: 6)
    ])
    
    let boardLattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 25 * h + 17 * h2k + 6 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Concave {
          Origin { 12 * h + 8 * h2k + 2.2 * l }
          
          // Cut a plane separating the back of the board from some open void.
          Plane { l }
          
          // Right hand side part that prevents the input rods from escaping
          // into the void.
          Concave {
            Convex {
              Origin { 6 * h }
              Concave {
                Plane { -h }
                Convex {
                  Origin { -2 * h + 4 * h2k }
                  Plane { k - h }
                  Plane { (-k - h) - h }
                }
                Convex {
                  Origin { -2 * h + 9 * h2k }
                  Plane { (-k - h) - h }
                }
              }
              Origin { 2 * h }
              Plane { h }
              Plane { -k }
            }
          }
          
          Convex {
            Origin { 10 * k }
            Plane { -k }
            Origin { 2 * k }
            Plane { k }
            Origin { 3 * h }
            Plane { h }
          }
          
          Convex {
            Concave {
              Origin { -2.5 * h }
              Plane { h }
              Origin { 5 * h }
              Plane { -h }
            }
            Convex {
              Convex {
                Origin { 8 * h }
                Plane { h }
              }
              Concave {
                Origin { -2.5 * k }
                Plane { k }
                Origin { 5 * k }
                Plane { -k }
              }
              Concave {
                Origin { 7.5 * k }
                Origin { -2.5 * k }
                Plane { k }
                Origin { 5 * k }
                Plane { -k }
              }
            }
            
            Concave {
              Convex {
                Origin { -4.5 * h }
                Plane { -h }
                Origin { 9 * h }
                Plane { h }
              }
              Convex {
                Origin { -4.5 * k }
                Plane { -k }
                Origin { 9.5 * k }
                Plane { k }
              }
              
              // Fix up some artifacts on the joint between two lines.
              Convex {
                Convex {
                  Origin { -3.5 * (k - h) }
                  Plane { -(k - h) }
                  Origin { 7 * (k - h) }
                  Plane { k - h }
                }
                Convex {
                  Origin { -3.5 * (k + h) }
                  Plane { -(k + h) }
                  Origin { 7 * (k + h) }
                  Plane { k + h }
                }
              }
            }
          }
          Replace { .empty }
        }
      }
      
      Volume {
        Origin { 5.2 * l }
        Plane { l }
        Replace { .empty }
      }
    }
    
    let rod1Lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 15 * h + 14 * h2k + 3 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Convex {
          Origin { 5 * k }
          Plane { -k }
        }
        Convex {
          Origin { 6.5 * k }
          Plane { k }
        }
        Convex {
          Origin { 2.2 * l }
          Plane { l }
        }
        Convex {
          Origin { 6 * (h + k) }
          Plane { -(h + k) }
        }
        Replace { .empty }
      }
    }
    
    let boardAtoms = boardLattice.entities.map(MRAtom.init)
    var boardDiamondoid = Diamondoid(atoms: boardAtoms)
    
    // TODO: Call removeLooseCarbons() before fixing the hydrogens.
    boardDiamondoid.fixHydrogens(tolerance: 0.08)
    boardDiamondoid.anchors = getBoardAnchors(
      carbons: boardDiamondoid.atoms.filter { $0.element == 6 },
      atoms: boardDiamondoid.atoms)
    provider = ArrayAtomProvider(boardDiamondoid.atoms)
    
    let h = SIMD3<Float>(1, 0, 0) * 0.252
    let k = SIMD3<Float>(-0.5, 0.866925, 0) * 0.252
    let l = SIMD3<Float>(0, 0, 1) * 0.412
    
    let rod1Atoms = rod1Lattice.entities.map(MRAtom.init)
    var rod1Diamondoid = Diamondoid(atoms: rod1Atoms)
    var rod2Diamondoid = rod1Diamondoid
    var rod3Diamondoid = rod1Diamondoid
    
    rod1Diamondoid.translate(offset: -rod1Diamondoid.createCenterOfMass())
    rod1Diamondoid.translate(offset: 4.25 * l)
    rod1Diamondoid.translate(offset: 6 * k)
    rod1Diamondoid.translate(offset: 4 * (k + 2 * h))
//    rod1Diamondoid.translate(offset: [0, 0, 3])
    
    rod2Diamondoid.translate(offset: -rod2Diamondoid.createCenterOfMass())
    rod2Diamondoid.translate(offset: 4.25 * l)
    rod2Diamondoid.translate(offset: 6 * k)
    rod2Diamondoid.translate(offset: 4 * (k + 2 * h))
    rod2Diamondoid.translate(offset: 5.1 * (h + 2 * k))
//    rod2Diamondoid.translate(offset: [0, 0, 4.5])
    
    rod3Diamondoid.translate(offset: -rod3Diamondoid.createCenterOfMass())
    rod3Diamondoid.rotate(angle: Quaternion<Float>(
      angle: 4 * .pi / 3, axis: [0, 0, 1]))
    rod3Diamondoid.translate(offset: 4.25 * l)
    rod3Diamondoid.translate(offset: 12 * h)
    rod3Diamondoid.translate(offset: 1 * (h + 2 * k))
//    rod3Diamondoid.translate(offset: [0, 0, 3])
    
    var diamondoids = [
      boardDiamondoid, rod1Diamondoid, rod2Diamondoid, rod3Diamondoid
    ]
    for diamondoidID in diamondoids.indices {
      diamondoids[diamondoidID].removeLooseCarbons()
    }
    print(ArrayAtomProvider(diamondoids).atoms.count)
    provider = ArrayAtomProvider(diamondoids)
    
    // Changes needed:
    // - Use another floating rod to drive the anchored-down ones forward. The
    //   contactless vdW force should drag the rod forward in the direction you
    //   want, if applied slowly enough. If the rod is geometrically blocked, it
    //   will not move.
    // - This mechanism allows a single, compact input mechanism to have high
    //   fan-out. However, one needs to ensure it doesn't geometrically
    //   interfere with other rods' input mechanisms.
    //
    // Solution 1:
    // - Maximize the distance between rods, minimize the distance traveled.
    // - This should allow clocking mechanisms to be a "comparatively small"
    //   nudge from a different rod perpendicular to rod 1, and above it.
    // - The clocking mechanism's displacement is so "comparatively small" that
    //   it can't geometrically crash into other rods' drivers.
    //
    // Solution 2:
    // - Manufacture two sheets, which have holes in the bottom. The holes allow
    //   a probe/gate knob like in Eric's design. This seems to be much more
    //   workable. It requires much smaller rod length, and clocking mechanisms
    //   on opposite sides (which won't interfere).
    // - Start out with a piece on the Z midpoint. Design each side of the sheet
    //   separately.
    
    #if false
    // Run the simulation.
    runSimulation(diamondoids: &diamondoids, minimize: true, time: 1)
    
    // Sequence:
    // 1 1
    // 1 0
    // 0 1
    // 0 0 -> output = 1
    func reset() {
      for i in 1...3 {
        diamondoids[i].externalForce = nil
      }
    }
    
    let rod1Direction = cross_platform_normalize(k + 2 * h)
    let rod2Direction = cross_platform_normalize(k + 2 * h)
    let rod3Direction = cross_platform_normalize(h + 2 * k)
    
    reset()
    if rod1True {
      diamondoids[1].externalForce = 550 * rod1Direction
    } else {
      diamondoids[1].externalForce = 110 * rod1Direction
    }
    if rod2True {
      diamondoids[2].externalForce = 500 * rod2Direction
    } else {
      diamondoids[2].externalForce = 100 * rod2Direction
    }
    runSimulation(diamondoids: &diamondoids, time: 8)
    
    reset()
    diamondoids[3].externalForce = 500 * rod3Direction
    if !rod1True && !rod2True {
      runSimulation(diamondoids: &diamondoids, time: 25)
    } else {
      runSimulation(diamondoids: &diamondoids, time: 12)
    }
    #endif
  }
  
  mutating func runSimulation(
    diamondoids: inout [Diamondoid],
    minimize: Bool = false,
    time: Double = 10
  ) {
    let simulator = MM4(diamondoids: diamondoids, fsPerFrame: 20)
    print("Simulating: \(simulator.newIndicesMap.count) atoms")
    if minimize {
      for _ in 0..<8 {
        simulator.simulate(ps: 0.5, minimizing: true)
        guard let numAtoms = simulator.provider.states.last?.count else {
          fatalError("Failed to get states.")
        }
        let velocities = [SIMD3<Float>](repeating: .zero, count: numAtoms)
        simulator.provider.reset()
        simulator.thermalize(velocities: velocities)
      }
    }
    simulator.simulate(ps: time)
    
    if openmmProvider == nil {
      self.provider = simulator.provider
      self.openmmProvider = simulator.provider
    } else {
      self.openmmProvider!.states += simulator.provider.states
    }
    guard let lastState = simulator.provider.states.last else {
      fatalError("No last state.")
    }
    var atomPointer = 0
    var diamondoidPointer = 0
    while atomPointer < lastState.count {
      let numAtoms = diamondoids[diamondoidPointer].atoms.count
      for i in 0..<numAtoms {
        diamondoids[diamondoidPointer].atoms[i] = lastState[atomPointer + i]
      }
      atomPointer += numAtoms
      diamondoidPointer += 1
    }
  }
  
  func getBoardAnchors(
    carbons: [MRAtom], atoms: [MRAtom]
  ) -> [Bool] {
    var minCoords: SIMD3<Float> = .init(repeating: .greatestFiniteMagnitude)
    var maxCoords: SIMD3<Float> = .init(repeating: -.greatestFiniteMagnitude)
    for atom in carbons {
      let center = atom.origin
      minCoords.replace(with: center, where: center .< minCoords)
      maxCoords.replace(with: center, where: center .> maxCoords)
    }
    minCoords += SIMD3(repeating: 0.010)
    maxCoords -= SIMD3(repeating: 0.010)
    maxCoords.z = .greatestFiniteMagnitude
    
    // Keep vibrations bound within the simulated box.
//    minCoords.x = -.greatestFiniteMagnitude
//    minCoords.y = -.greatestFiniteMagnitude
//    maxCoords.x = .greatestFiniteMagnitude
//    maxCoords.y = .greatestFiniteMagnitude
    
    return atoms.map { atom in
      let center = atom.origin
      if any(center .< minCoords) {
        return true
      }
      if any(center .> maxCoords) {
        return true
      }
      return false
    }
  }
}

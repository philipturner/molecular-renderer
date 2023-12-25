//
//  RippleCounter.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 11/3/23.
//

import Foundation
import HDL
import MolecularRenderer
import QuaternionModule

// Create some logic gates in this file, then extract them to the hardware
// catalog once you want to instantiate them multiple times. Transfer the code
// from this file to the hardware catalog.

// TODO: Make another file for the second attempt, called
// "RippleCounter2". Use this naming convention for future systems with multiple
// design iterations.

// 4-bit ripple counter using nanomechanical logic, combinational and serial
struct RippleCounter1 {
  var provider: any MRAtomProvider
  var openmmProvider: OpenMM_AtomProvider?
  
  init() {
    self.provider = ArrayAtomProvider([MRAtom(origin: .zero, element: 6)])
    
    // First step: create a board that's anchored in place using MM4 anchors,
    // but sufficiently deep to account for thermodynamic effects.
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 30 * h + 10 * h2k + 20 * l }
      Material { .elemental(.carbon) }
      
      // Create grooves for logic gates by calling Concave on the parent
      // lattice. This is an alternative form of CSG, as the Solid API from the
      // HDL is still unfinished.
      Volume {
        // Origin starts at (0, 0) instead of the middle. This allows stuff to
        // be specified on a finitely bounded coordinate system more easily.
        Origin { 2 * h2k }
        Concave {
          Plane { h2k }
          
          // A function for easily adding cuboids to the base lattice.
          func cuboid(start: SIMD3<Float>, end: SIMD3<Float>) {
            Convex {
              Convex {
                Origin { start.x * h + start.y * h2k + start.z * l }
                Plane { -h }
                Plane { -h2k }
                Plane { -l }
              }
              Convex {
                Origin { end.x * h + end.y * h2k + end.z * l }
                Plane { h }
                Plane { h2k }
                Plane { l }
              }
            }
          }
          
          // Fixes issues with the cuboid connecting to the lattice.
          func bottomConnector(start: SIMD3<Float>, end: SIMD3<Float>) {
            Convex {
              Convex {
                Origin { start.x * h + 0.5 * h2k + start.z * l }
                Plane { -1 * h + 1 * h2k }
                Plane { -4 * l + 1 * h2k }
              }
              Convex {
                Origin { end.x * h + 0.5 * h2k + end.z * l }
                Plane { 1 * h + 1 * h2k }
                Plane { 4 * l + 1 * h2k }
              }
            }
          }
          
          func bottomCuboid(start: SIMD3<Float>, end: SIMD3<Float>) {
            Concave {
              cuboid(start: start, end: end)
              bottomConnector(start: start, end: end)
            }
          }
          
          for offset in [Float(0), 5] {
            Concave {
              Origin { offset * l }
              bottomCuboid(start: [2, 0, 2], end: [5, 3.5, 3.7])
              bottomCuboid(start: [5.5, 0, 2], end: [8.5, 1.5, 3.7])
              bottomCuboid(start: [9, 0, 2], end: [12, 3.5, 3.7])
              bottomCuboid(start: [12.5, 0, 2], end: [15, 1.5, 3.7])
            }
          }
          
        }
        Replace { .empty }
      }
    }
    
    // Another Lattice for the logic rods that go on the sliding positions.
    
    let board = lattice.entities.map(MRAtom.init)
    var boardDiamondoid = Diamondoid(atoms: board)
    boardDiamondoid.fixHydrogens(tolerance: 0.08)
    boardDiamondoid.anchors = getBoardAnchors(
      carbons: board, atoms: boardDiamondoid.atoms)
    
    let logicRod1 = logicRod1()
    var logicRod1Diamondoid = Diamondoid(atoms: logicRod1)
    logicRod1Diamondoid.fixHydrogens(tolerance: 0.08)
    logicRod1Diamondoid.translate(
      offset: -logicRod1Diamondoid.createCenterOfMass())
    logicRod1Diamondoid.rotate(
      angle: Quaternion<Float>(angle: .pi / 2, axis: [0, 1, 0]))
    logicRod1Diamondoid.translate(offset: [2, 2.6, 2.2])
    logicRod1Diamondoid.externalForce = [500, 0, 0]
    
    let firstVisualizedAtoms = logicRod1Diamondoid.atoms
    self.provider = ArrayAtomProvider(firstVisualizedAtoms)
    
    var diamondoids: [Diamondoid] = []
    diamondoids.append(boardDiamondoid)
    diamondoids.append(logicRod1Diamondoid)
    self.visualizeDiamondoids(diamondoids)
    self.runSimulation(diamondoids: &diamondoids, minimize: true)
    
    diamondoids[1].externalForce = nil
    self.runSimulation(diamondoids: &diamondoids, time: 10)
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
    maxCoords.y = .greatestFiniteMagnitude
    
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
  
  func visualizeBoardAnchors(
    atoms: [MRAtom], anchors: [Bool]
  ) -> [MRAtom] {
    return zip(atoms, anchors).map { atom, anchor in
      guard anchor else {
        return atom
      }
      var output = atom
      if atom.element == 6 {
        output.element = 14
      } else if atom.element == 1 {
        output.element = 9
      }
      return output
    }
  }
  
  mutating func visualizeDiamondoids(_ diamondoids: [Diamondoid]) {
    var atoms: [MRAtom] = []
    for diamondoid in diamondoids {
      atoms.append(contentsOf: diamondoid.atoms)
    }
    print("Visualizing: \(atoms.count) atoms")
    self.provider = ArrayAtomProvider(atoms)
  }
}

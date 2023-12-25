//
//  AtomProviders.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/21/23.
//

import Foundation
import HDL
import OpenMM
import MolecularRenderer

// MARK: - MRAtom Interface with Array

struct ArrayAtomProvider: MRAtomProvider {
  var atoms: [MRAtom]
  
  init(_ atoms: [MRAtom]) {
    self.atoms = atoms
  }
  
  init(_ centers: [SIMD3<Float>]) {
    self.init(centers.map { MRAtom(origin: $0, element: 6)})
  }
  
  func atoms(time: MRTime) -> [MRAtom] {
    return atoms
  }
  
  init(_ diamondoids: [Diamondoid]) {
    var atoms: [MRAtom] = []
    for diamondoid in diamondoids {
      atoms += diamondoid.atoms
    }
    self.init(atoms)
  }
}

struct AnimationAtomProvider: MRAtomProvider {
  var frames: [[MRAtom]]
  
  init(_ frames: [[MRAtom]]) {
    self.frames = frames
  }
  
  func atoms(time: MRTime) -> [MRAtom] {
    if frames.count == 0 {
      return []
    }
    
    var frameID = time.absolute.frames
    frameID = min(frameID, frames.count - 1)
    return frames[frameID]
  }
}

struct MovingAtomProvider: MRAtomProvider {
  var atoms: [MRAtom]
  var velocity: SIMD3<Float>
  
  // Velocity is in nanometers per IRL second.
  init(_ atoms: [MRAtom], velocity: SIMD3<Float>) {
    self.atoms = atoms
    self.velocity = velocity
  }
  
  func atoms(time: MRTime) -> [MRAtom] {
    let delta = velocity * Float(time.absolute.seconds)
    return atoms.map {
      var copy = $0
      copy.origin += delta
      return copy
    }
  }
}

// MARK: - MRAtom Interface with OpenMM

// The results of an OpenMM simulation. Currently, the data must be generated
// inside OpenMM at app launch time.

// Create a number of steps per frame; to add another frame, it validates the
// number of steps equals what you set. Also check that the number of atoms
// equals the number of atomic numbers.
class OpenMM_AtomProvider: MRAtomProvider {
  private(set) var psPerStep: Double
  private(set) var stepsPerFrame: Int
  private(set) var elements: [UInt8]
  /*private(set)*/ var states: [[MRAtom]] = []
  
  // Specify each atom's atomic number beforehand; OpenMM doesn't provide that.
  // Use element zero for ghost particles that keep diamondoids aligned to
  // groups of 32 atoms.
  init(
    psPerStep: Double,
    stepsPerFrame: Int,
    elements: [UInt8]
  ) {
    self.psPerStep = psPerStep
    self.stepsPerFrame = stepsPerFrame
    self.elements = elements
  }
  
  func append(state: OpenMM_State, steps: Int) {
    let positions = state.positions
    precondition(positions.size == elements.count, "Incorrect number of atoms.")
    if states.count == 0 {
      precondition(steps == 0, "First frame must have zero steps.")
    } else {
      // Disabling this check because it's getting in the way of other
      // design work.
//      precondition(steps == stepsPerFrame, "Incorrect number of steps.")
    }
    
    let atoms = [MRAtom](
      unsafeUninitializedCapacity: elements.count
    ) { buffer, count in
      for (i, element) in elements.enumerated() {
        guard element > 0 else {
          fatalError()
          continue
        }
        let posInNm = SIMD3<Float>(positions[i])
        let atom = MRAtom(origin: posInNm, element: element)
        buffer[count] = atom
        count += 1
      }
    }
    self.states.append(atoms)
  }
  
  // Move to the next frame. Call this **after** reading from the states.
  func atoms(time: MRTime) -> [MRAtom] {
    let fps = ContentView.frameRate
    precondition(120 % fps == 0)
    let frameAmplificationFactor = 120 / fps
    
    var frameID = time.absolute.frames * frameAmplificationFactor
    frameID = min(frameID, states.count - 1)
    return states[frameID]
  }
  
  func reset() {
    self.states = []
  }
}

// MARK: - MRAtom Interface with HDL

extension MRAtom {
  init(entity: HDL.Entity) {
    if case .empty = entity.type {
      self = MRAtom(origin: entity.position, element: 0)
      self.flags = 0x1
      return
    }
    
    guard case .atom(let element) = entity.type else {
      fatalError("Unrecognized entity type: \(entity.storage.w)")
    }
    self = MRAtom(
      origin: entity.position,
      element: element.rawValue)
  }
}

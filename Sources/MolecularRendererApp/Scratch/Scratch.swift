// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

// Create a setup that can test all of the 2-input gates.
// - Use the new "Collision Detection" level of theory.
//
// Speculation about how one would explain the levels of theory in
// a video:
//
// There are four levels of theory:
// - Semiempirical Quantum Mechanics
//   - CBN tripod adding carbenic feedstock to logic rod fragment,
//     with frame interpolation *
// - Molecular Mechanics
//   - Obstructed and mobile states of a single logic switch
// - Rigid Body Mechanics
//   - Experiment with the SiC drive wall, with a cross-section
// - Collision Detection
//   - Clock cycle of a 4-bit RCA, with housing omitted
//
// Multiscale simulation enables the design and testing of
// large nanosystems, in full atomic detail.
//
// With only the compute power of a single GPU.
//
// * Project idea: simulate the CBN tripod HDon reaction with frame
//   interpolation. Profile xTB in Xcode, to see whether most of the
//   time is spent in LAPACK.
// * Can the carbene idea be used to complete a diamond cage in the
//   (111) orientation, with 1 DOF?
//
// The mechanosynthesis part seems out of scope for such a video, and could
// take away some very critical time required to get it done (or time that
// could be spent developing DFT software). Remove this level of theory from
// such an explanation, resulting in three levels.
func createGeometry() -> [[Entity]] {
  let inputRodLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 15 * h + 2 * h2k + 2 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Origin { 1.5 * h2k }
      Concave {
        Plane { h2k }
        Origin { 3 * h }
        Plane { -h }
      }
      Concave {
        Plane { h2k }
        Origin { 7 * h }
        Plane { h }
      }
      Replace { .empty }
    }
  }
  
  let outputRodLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 25 * h + 2 * h2k + 2 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Origin { 1.5 * h2k }
      Concave {
        Plane { h2k }
        Origin { 3 * h }
        Plane { -h }
      }
      Concave {
        Plane { h2k }
        Origin { 7 * h }
        Plane { h }
        Origin { 7 * h }
        Plane { -h }
      }
      Concave {
        Plane { h2k }
        Origin { 18 * h }
        Plane { h }
      }
      Replace { .empty }
    }
  }
  
  // Set the starting position for the first input rod.
  var atomsInput1 = inputRodLattice.atoms
  for atomID in atomsInput1.indices {
    var atom = atomsInput1[atomID]
    atom.position.y = -atom.position.y
    atom.position.y += 1.9
    atom.position = SIMD3(
      atom.position.z, atom.position.y, atom.position.x)
    atom.position.z += -0.9
    atomsInput1[atomID] = atom
  }
  
  // Set the starting position for the second input rod.
  var atomsInput2 = atomsInput1
  for atomID in atomsInput2.indices {
    var atom = atomsInput2[atomID]
    atom.position.x += 2.8
    atomsInput2[atomID] = atom
  }
  
  #if false
  do {
    var atomsInput = atomsInput1
    
    // Change into a NOT gate.
    var inputCenterOfMass: SIMD3<Float> = .zero
    for atom in atomsInput {
      inputCenterOfMass += atom.position
    }
    inputCenterOfMass /= Float(atomsInput.count)
    for atomID in atomsInput.indices {
      var atom = atomsInput[atomID]
      var deltaZ = atom.position.z - inputCenterOfMass.z
      deltaZ = -deltaZ
      atom.position.z = deltaZ + inputCenterOfMass.z
      atomsInput[atomID] = atom
    }
    
    atomsInput1 = atomsInput
  }
  #endif
  
  #if false
  do {
    var atomsInput = atomsInput2
    
    // Change into a NOT gate.
    var inputCenterOfMass: SIMD3<Float> = .zero
    for atom in atomsInput {
      inputCenterOfMass += atom.position
    }
    inputCenterOfMass /= Float(atomsInput.count)
    for atomID in atomsInput.indices {
      var atom = atomsInput[atomID]
      var deltaZ = atom.position.z - inputCenterOfMass.z
      deltaZ = -deltaZ
      atom.position.z = deltaZ + inputCenterOfMass.z
      atomsInput[atomID] = atom
    }
    
    atomsInput2 = atomsInput
  }
  #endif
  
  // Set the starting position for the output rod.
  var atomsOutput = outputRodLattice.atoms
  for atomID in atomsOutput.indices {
    var atom = atomsOutput[atomID]
    atom.position.x += -2.3
    atomsOutput[atomID] = atom
  }
  
  // Setup:
  // - Move the input rods forward, independently of whether you
  //   turned them into NOT gates. Specify an array of input bits
  //   and print a bit representing the output to the console.
  var descriptor = SimulationDescriptor()
  descriptor.atomsInput1 = atomsInput1
  descriptor.atomsInput2 = atomsInput2
  descriptor.atomsOutput = atomsOutput
  descriptor.inputBits = [true, true]
  
  var simulation = Simulation(descriptor: descriptor)
  for _ in 0..<300 {
    simulation.step()
  }
  print("output:", simulation.result.outputBit)
  
  // Next: print a truth table to the console for each given input. Exit the
  // program early and do not render the output.
  
  return simulation.result.frames
}

struct SimulationDescriptor {
  var atomsInput1: [Entity]?
  var atomsInput2: [Entity]?
  var atomsOutput: [Entity]?
  var inputBits: [Bool]?
}

struct SimulationResult {
  var frames: [[Entity]] = []
  var outputBit: Bool = true
}

struct Simulation {
  var atomsInput1: [Entity]
  var atomsInput2: [Entity]
  var atomsOutput: [Entity]
  var inputBits: [Bool]
  
  var result: SimulationResult = .init()
  
  init(descriptor: SimulationDescriptor) {
    guard let atomsInput1 = descriptor.atomsInput1,
          let atomsInput2 = descriptor.atomsInput2,
          let atomsOutput = descriptor.atomsOutput,
          let inputBits = descriptor.inputBits else {
      fatalError("Simulation not fully specified.")
    }
    self.atomsInput1 = atomsInput1
    self.atomsInput2 = atomsInput2
    self.atomsOutput = atomsOutput
    self.inputBits = inputBits
    setInputs()
  }
  
  mutating func setInputs() {
    for _ in 0..<60 {
      if inputBits[0] {
        for atomID in atomsInput1.indices {
          atomsInput1[atomID].position.z += -0.02
        }
      }
      if inputBits[1] {
        for atomID in atomsInput2.indices {
          atomsInput2[atomID].position.z += -0.02
        }
      }
      
      let frame = self.atomsInput1 + self.atomsInput2 + self.atomsOutput
      result.frames.append(frame)
    }
  }
  
  mutating func step() {
    var nextAtomsOutput = atomsOutput
    for atomID in nextAtomsOutput.indices {
      nextAtomsOutput[atomID].position.x += 0.02
    }
    
    var topology = Topology()
    topology.insert(atoms: atomsInput1)
    topology.insert(atoms: atomsInput2)
    let matches = topology.match(
      nextAtomsOutput, algorithm: .covalentBondLength(3),
      maximumNeighborCount: 16)
    
    var foundMatch = false
    for atomID in nextAtomsOutput.indices {
      if matches[atomID].count > 0 {
        foundMatch = true
      }
    }
    if foundMatch {
      // Do nothing.
      result.outputBit = false
    } else {
      // Advance the output if there is no collision.
      atomsOutput = nextAtomsOutput
    }
    
    let frame = atomsInput1 + atomsInput2 + atomsOutput
    result.frames.append(frame)
  }
}

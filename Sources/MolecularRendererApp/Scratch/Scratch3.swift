//
//  Scratch3.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/4/24.
//

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

// Accepts the topology for just one crystolecule, instantiates the rest.
func createAnimation(_ topology: Topology) -> AnimationAtomProvider {
  var stepEnergies: [[Float]] = []
  stepEnergies = Array(repeating: [], count: 25)
  var potentialEnergies: [Double] = []
  var stepFs: [Float] = []
  
  for trialID in 0..<5 {
    var fs: Double
    if trialID < 1 {
      fs = 2
    } else if trialID < 2 {
      fs = 1
    } else if trialID < 3 {
      fs = 0.5
    } else if trialID < 4 {
      fs = 0.25
    } else {
      fs = 0.125
    }
    stepFs.append(Float(fs))
    
    var descriptor = TopologyMinimizerDescriptor()
    do {
      let platforms = OpenMM_Platform.platforms
      for platform in platforms {
        print(platform.name)
        
        let names = platform.propertyNames
        for i in 0..<names.size {
          let name = names[i]
          let value = platform.getPropertyDefaultValue(name)
          print("-", name, value)
        }
        if platform.name == "HIP" {
          descriptor.platform = platform
        }
      }
    }
    descriptor.timeStep = 0.001 * Double(fs)
    descriptor.topology = createScene(topology)
    
//    print(descriptor.topology.atoms)
    
    var minimizer = TopologyMinimizer(descriptor: descriptor)
    minimizer.minimize()
    
    var provider = AnimationAtomProvider([])
    provider.frames.append(minimizer.topology.atoms.map(MRAtom.init))
    
    //  let totalTime: Double = 10
    //  let frameTime = totalTime / 500
    //  for _ in 0..<Int(totalTime/frameTime) {
    //    minimizer.simulate(time: frameTime)
    //    provider.frames.append(minimizer.topology.atoms.map(MRAtom.init))
    //  }
    
    let initialPotential = minimizer.createPotentialEnergy()
    potentialEnergies.append(initialPotential)
    let start = cross_platform_media_time()
    for i in 0..<25 {
      print("timestep \(i)")
      minimizer.simulate(time: 0.004)
      let kinetic = minimizer.createKineticEnergy()
      let potential = minimizer.createPotentialEnergy() - initialPotential
      let total = kinetic + potential
      stepEnergies[i].append(Float(total))
      
      //    print("potential: \(String(format: "%.2f", potential)) zJ, kinetic: \(String(format: "%.2f", kinetic)) zJ, total: \(String(format: "%.2f", kinetic + potential)) zJ")
      provider.frames.append(minimizer.topology.atoms.map(MRAtom.init))
    }
    let end = cross_platform_media_time()
    print("Execution Time: \(Float(end - start)) @ \(String(format: "%.2f", fs)) fs")
  }
  
  // Run this experiment with GPU. Then, repeat with CPU. Analyze the difference
  // in graphs of energy variation. This will inform whether to include a
  // "high-precision" mode for extracting energy from MM4ForceField.
  //
  // Retry by shifting potentials by the value of their well depth. That may
  // reduce the absolute value of potential energy, improving the relative
  // precision of GPU energy. Finally, just out of curiosity, see what happens
  // when you set METAL_REDUCE_ENERGY_THREADGROUPS to a very large number (maybe
  // even proportional to atom count). You'll need to recompile the Metal plugin
  // with the accumulator at FP64.
  //
  // The solution might be this combination:
  // - Minimize the absolute value of potential energy
  // - Set METAL_REDUCE_ENERGY_THREADGROUPS to something large.
  //   - Fix the Metal plugin, update to OpenMM 8.1.0
  // - Have one common GPU platform, no falling back to CPU or lazily
  //   initializing anything.
  // - Encourage users to install the Metal plugin on Apple silicon. Otherwise,
  //   select a mixed-precision platform if available. Otherwise, use OpenCL
  //   with only single precision available and worse energy accumulation.
  //   - This may slightly harm performance on non-Apple devices, but it's the
  //     simplest solution I can think of. M1 (2.6 TFLOPS) is a very weak GPU
  //     that needs every optimization possible. Maximizing speed is less of a
  //     priority on massive compute clusters, where the use case is often
  //     non-interactive overnight simulations.
  //   - NVE simulations with an extremely small timestep are not viable in any
  //     reasonable workflow. The only time you might use them, is when you have
  //     an absurd amount of compute. That coincides with this esoteric use case
  //     only functioning correctly on non-Apple GPUs.
  // - API convention that energies are in double precision. Every other
  //   quantity, including mass, is in single precision. Explain why this is;
  //   potential energies can have extremely large magnitudes, and the quantity
  //   of interest is differences between potential energies. The differences
  //   are often a fraction of total energy (1e-7) that cannot be represented by
  //   an FP32 mantissa.
  //
  // TODO: Important change of plans. Create a force field descriptor specifying
  // the OpenMM platform, precision, and parameters. This is a more flexible API
  // that's less ergonomic than init(rigidBodies:). It uses the defaults above,
  // which should work for every conceivable use case. However, users should
  // technically have the freedom to choose. They can copy the source code of
  // 'MM4ForceField.init(rigidBodies:)' and call the more tedious initializer
  // directly, if they wish.
  //
  // MM4ForceFieldDescriptor properties:
  // - parameters
  // - platform, type 'OpenMM_Platform?' so users can customize things like
  //   precision in the future
  //
  // <s>
  // - platform precision
  // </s>
  // The OpenMM 8.0.0 C wrapper lacks the proper API to set the precision
  // property. This leads to an even better design choice, which sticks with the
  // original desire. Force all double-precision stuff onto CPU to provide
  // equality between GPU vendors. This removes the need to update the Metal
  // plugin and makes the library's internal behavior simpler to understand.
  // - CPU platform always uses mixed precision; note that this is preferred for
  //   evaluating single-point energies
  // - GPU platform always uses single precision, regardless of whether the
  //   hardware has some FP64 units
  // - maximum performance on all GPU platforms, including Metal, by not forcing
  //   simulation and minimization to use mixed precision
  //
  // <s>
  // - positions
  // - velocities
  // - external forces
  //   (to avoid I/O into OpenMM twice; necessary for performance)
  // </s> too many sources of truth
  //
  // init(rigidBodies:) is a `convenience init`.
  do {
    var output = "potential energy"
    for potentialEnergy in potentialEnergies {
      output += ", " + String(format: "%.3f", potentialEnergy)
    }
    print(output)
  }
  do {
    var output = "time \\ time step (fs)"
    for fs in stepFs {
      output += ", " + String(format: "%.3f", fs)
    }
    print(output)
  }
  
  for i in stepEnergies.indices {
    var output = "\(4 * i), "
    while output.count < 7 {
      output = " " + output
    }
    
    let list = stepEnergies[i]
    for i in list.indices {
      var repr = String(format: "%.3f", list[i])
      while repr.count < 6 {
        repr = " " + repr
      }
      output += repr
      if i < list.count - 1 {
        output += ", "
      }
    }
    print(output)
  }
  exit(0)
}

func createScene(_ topology: Topology) -> Topology {
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = topology.bonds
  let params = try! MM4Parameters(descriptor: paramsDesc)
  
  var mainRigidBody = MM4RigidBody(parameters: params)
  mainRigidBody.setPositions(topology.atoms.map(\.position))
  
  var sceneTopology = Topology()
  func addRigidBody(_ rigidBody: MM4RigidBody) {
    var insertedAtoms: [Entity] = []
    for i in rigidBody.parameters.atoms.indices {
      let atomicNumbers = rigidBody.parameters.atoms.atomicNumbers
      let element = Element(rawValue: atomicNumbers[i])!
      let position = rigidBody.positions[i]
      let entity = Entity(position: position, type: .atom(element))
      insertedAtoms.append(entity)
    }
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for bond in rigidBody.parameters.bonds.indices {
      let mappedBond = bond &+ UInt32(sceneTopology.atoms.count)
      insertedBonds.append(mappedBond)
    }
    
    sceneTopology.insert(atoms: insertedAtoms)
    sceneTopology.insert(bonds: insertedBonds)
  }
  
  let rigidBodyCount = 4
  for i in 0..<rigidBodyCount {
    var rigidBody = mainRigidBody
    
//    rigidBody.centerOfMass.y += Float(i) * 1.7
    
//    print("START=========")
//    print(rigidBody.positions)
//    print(rigidBody.vectorizedPositions[rigidBody.vectorizedPositions.count - 3])
//    print(rigidBody.vectorizedPositions[rigidBody.vectorizedPositions.count - 2])
//    print(rigidBody.vectorizedPositions[rigidBody.vectorizedPositions.count - 1])
//    print(rigidBody.centerOfMass)
//    print(i)
//    print("MIDDLE=========")
    rigidBody.centerOfMass.x += Float(i) * 0.5
    rigidBody.centerOfMass.z += Float(i) * 0.72
//    print(rigidBody.positions)
//    print(rigidBody.vectorizedPositions[rigidBody.vectorizedPositions.count - 3])
//    print(rigidBody.vectorizedPositions[rigidBody.vectorizedPositions.count - 2])
//    print(rigidBody.vectorizedPositions[rigidBody.vectorizedPositions.count - 1])
//    print("END=========")
    
    addRigidBody(rigidBody)
  }
  
  return sceneTopology
}

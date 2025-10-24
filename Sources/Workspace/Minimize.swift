import HDL
import var MM4.MM4YgPerAmu
import xTB

func runMinimization(tripod: Topology) -> [[SIMD4<Float>]] {
  var calculatorDesc = xTB_CalculatorDescriptor()
  calculatorDesc.atomicNumbers = tripod.atoms.map(\.atomicNumber)
  let calculator = xTB_Calculator(descriptor: calculatorDesc)
  
  var minimizationDesc = FIREMinimizationDescriptor()
  minimizationDesc.anchors = [UInt32(0)] // apex atom
  minimizationDesc.masses = tripod.atoms.map {
    if $0.atomicNumber == 1 {
      return Float(4.0 * 1.660539)
    } else {
      return Float(12.011 * 1.660539)
    }
  }
  minimizationDesc.positions = tripod.atoms.map(\.position)
  var minimization = FIREMinimization(descriptor: minimizationDesc)
  
  // Find the sulfur indices.
  var sulfurIDs: [UInt32] = []
  for atomID in tripod.atoms.indices {
    let atom = tripod.atoms[atomID]
    if atom.element == .sulfur {
      sulfurIDs.append(UInt32(atomID))
    }
  }
  
  guard sulfurIDs.count == 3 else {
    fatalError("Failed to locate all the sulfurs on the legs.")
  }
  
  var frames: [[Atom]] = []
  func createFrame() -> [Atom] {
    var output: [Atom] = []
    for atomID in tripod.atoms.indices {
      var atom = tripod.atoms[atomID]
      let position = minimization.positions[atomID]
      atom.position = position
      output.append(atom)
    }
    return output
  }
  
  print()
  for trialID in 0..<500 {
    frames.append(createFrame())
    calculator.molecule.positions = minimization.positions
    
    // Enforce the constraints on leg sulfurs.
    var forces = calculator.molecule.forces
    do {
      var forceAccumulator: Float = .zero
      for atomID in sulfurIDs {
        let force = forces[Int(atomID)]
        forceAccumulator += force.y
      }
      forceAccumulator /= 3
      for atomID in sulfurIDs {
        var force = forces[Int(atomID)]
        force.y = forceAccumulator
        forces[Int(atomID)] = force
      }
    }
    
    var maximumForce: Float = .zero
    for atomID in calculator.molecule.atomicNumbers.indices {
      if minimization.anchors.contains(UInt32(atomID)) {
        continue
      }
      let force = forces[atomID]
      let forceMagnitude = (force * force).sum().squareRoot()
      maximumForce = max(maximumForce, forceMagnitude)
    }
    
    print("time: \(Format.time(minimization.time))", terminator: " | ")
    print("energy: \(Format.energy(calculator.energy))", terminator: " | ")
    print("max force: \(Format.force(maximumForce))", terminator: " | ")
    
    let converged = minimization.step(forces: forces)
    if !converged {
      print("Δt: \(Format.time(minimization.Δt))", terminator: " | ")
    }
    print()
    
    // Enforce the constraints on leg sulfurs.
    do {
      var positions = minimization.positions
      var positionAccumulator: Float = .zero
      for atomID in sulfurIDs {
        let position = positions[Int(atomID)]
        positionAccumulator += position.y
      }
      positionAccumulator /= 3
      for atomID in sulfurIDs {
        var position = positions[Int(atomID)]
        position.y = positionAccumulator
        positions[Int(atomID)] = position
      }
      minimization.positions = positions
    }
    
    if converged {
      print("converged at trial \(trialID)")
      frames.append(createFrame())
      break
    } else if trialID == 499 {
      print("failed to converge!")
    }
  }
  
  return frames
}

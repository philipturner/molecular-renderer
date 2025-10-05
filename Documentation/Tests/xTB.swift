import HDL
import MolecularRenderer
import xTB

let system: [Atom] = [
  Atom(position: SIMD3(0.000, 0.000, 0.000), element: .nitrogen),
  Atom(position: SIMD3(0.109, 0.000, 0.000), element: .nitrogen),
]

// Create the calculator.
var calculatorDesc = xTB_CalculatorDescriptor()
calculatorDesc.atomicNumbers = system.map(\.atomicNumber)
calculatorDesc.hamiltonian = .tightBinding
let calculator = xTB_Calculator(descriptor: calculatorDesc)

// Update the positions. When using `.tightBinding`, the positions can be
// specified after initializing the calculator.
calculator.molecule.positions = system.map(\.position)

// Query the energy.
do {
  let expectedEnergy: Double = -25128.461
  let actualEnergy: Double = calculator.energy
  guard (expectedEnergy - actualEnergy).magnitude < 0.001 else {
    fatalError("Calculator returned unexpected energy: \(actualEnergy) zJ")
  }
}

// Survey the potential energy curve.
let candidateBondLengths: [Float] = [
  0.090, // 1.70 Bohr
  0.100, // 1.89 Bohr
  0.110, // 2.08 Bohr
  0.120, // 2.27 Bohr
  0.130, // 2.46 Bohr
  0.140, // 2.65 Bohr
  0.150, // 2.83 Bohr
  0.160, // 3.02 Bohr
]
var candidateEnergies: [Double] = []
for bondLength in candidateBondLengths {
  let position = SIMD3<Float>(bondLength, 0, 0)
  calculator.molecule.positions[1] = position
  
  let energy = calculator.energy
  candidateEnergies.append(energy)
}

// Display the relative energies in the console.
let energyMinimum: Double = -25129.268
for i in candidateBondLengths.indices {
  let bondLength = candidateBondLengths[i]
  let bondLengthRepr = String(format: "%.3f", bondLength)
  
  let energy = candidateEnergies[i]
  let relativeEnergy = Float(energy - energyMinimum)
  var relativeEnergyRepr = String(format: "%.1f", relativeEnergy)
  while relativeEnergyRepr.count < 6 {
    relativeEnergyRepr = " " + relativeEnergyRepr
  }
  print("\(bondLengthRepr) nm - \(relativeEnergyRepr) zJ")
}

// Check that the energies match expectations.
let expectedRelativeEnergies: [Float] = [
  Float( 821.2), // 0.18 Ha
  Float( 152.6), // 0.04 Ha
  Float(   0.0), // 0.00 Ha
  Float(  99.2), // 0.02 Ha
  Float( 311.2), // 0.07 Ha
  Float( 563.4), // 0.13 Ha
  Float( 818.5), // 0.19 Ha
  Float(1057.6), // 0.24 Ha
]
for i in candidateBondLengths.indices {
  let expectedEnergy = expectedRelativeEnergies[i]
  
  let absoluteEnergy = candidateEnergies[i]
  let actualEnergy = Float(absoluteEnergy - energyMinimum)
  guard (expectedEnergy - actualEnergy).magnitude < 0.1 else {
    fatalError("Got unexpected relative energy: \(actualEnergy) zJ")
  }
}

// Numerically calculate the force, compare to analytical force.
xTB_Environment.verbosity = .muted
print()
for i in 1..<candidateBondLengths.count {
  let leftBondLength = candidateBondLengths[i - 1]
  let rightBondLength = candidateBondLengths[i]
  let midPoint = (leftBondLength + rightBondLength) / 2
  
  // Evaluate the force analytically.
  let position = SIMD3<Float>(midPoint, 0, 0)
  calculator.molecule.positions[1] = position
  let force0 = calculator.molecule.forces[0]
  let force1 = calculator.molecule.forces[1]
  
  // Evaluate the force numerically.
  let leftEnergy = candidateEnergies[i - 1]
  let rightEnergy = candidateEnergies[i]
  let energyDifference = Float(rightEnergy - leftEnergy)
  let distanceChange = rightBondLength - leftBondLength
  let energyGradient = energyDifference / distanceChange
  
  func format(force: Float) -> String {
    var output = String(format: "%.0f", force)
    while output.count < 7 {
      output = " " + output
    }
    return output
  }
  
  let midPointRepr = String(format: "%.3f", midPoint)
  let energyGradientRepr = format(force: energyGradient)
  let force0Repr = format(force: force0.x)
  let force1Repr = format(force: force1.x)
  
  print(
    "\(midPointRepr) nm -",
    "\(energyGradientRepr) pN",
    "(\(force0Repr) pN, \(force1Repr) pN)")
}

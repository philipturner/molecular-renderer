import HDL
import MM4
import MolecularRenderer
import QuaternionModule
import xTB

let system: [Atom] = [
  Atom(position: SIMD3(0.000, 0.000, 0.000), element: .nitrogen),
  Atom(position: SIMD3(1.090, 0.000, 0.000), element: .nitrogen),
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
  let expectedEnergy: Double = -22755.932
  let actualEnergy: Double = calculator.energy
  guard (expectedEnergy - actualEnergy).magnitude < 0.001 else {
    fatalError("Calculator returned unexpected energy: \(actualEnergy) zJ")
  }
}

// Survey the potential energy curve.
let candidateBondLengths: [Float] = [
  1.00, 1.10, 1.20
]
var candidateEnergies: [Float] = []
for bondLength in candidateBondLengths {
  let position = SIMD3<Float>(bondLength, 0, 0)
  calculator.molecule.positions[1] = position
  
  //let energy = calculator.energy
  //candidateEnergies.append(energy)
}
for i in candidateBondLengths.indices {
  let bondLength = candidateBondLengths[i]
  let bondLengthRepr = String(format: "%.3f", bondLength)
  print(bondLengthRepr)
}

// TODO: Numerically calculate the force, compare to analytical force.

import HDL
import MM4
import MolecularRenderer
import QuaternionModule
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
// do {
//   let expectedEnergy: Double = -22755.932
//   let actualEnergy: Double = calculator.energy
//   guard (expectedEnergy - actualEnergy).magnitude < 0.001 else {
//     fatalError("Calculator returned unexpected energy: \(actualEnergy) zJ")
//   }
// }
print(calculator.energy)

// Survey the potential energy curve.
let candidateBondLengths: [Float] = [
  0.90, 1.00, 1.10, 1.20, 1.30
]
var candidateEnergies: [Double] = []
for bondLength in candidateBondLengths {
  let position = SIMD3<Float>(bondLength, 0, 0)
  calculator.molecule.positions[1] = position
  
  let energy = calculator.energy
  candidateEnergies.append(energy)
}
for i in candidateBondLengths.indices {
  let bondLength = candidateBondLengths[i]
  let bondLengthRepr = String(format: "%.3f", bondLength)
  
  let energy = candidateEnergies[i]
  let energyRepr = String(format: "%.1f", energy)
  
  print(bondLength, "nm", "-", energyRepr, "zJ")
}

// TODO: Numerically calculate the force, compare to analytical force.

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
print(calculator.energy)

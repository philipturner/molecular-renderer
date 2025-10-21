import HDL
import MM4
import MolecularRenderer
import QuaternionModule
import xTB

// MARK: - Compile Structure

func passivate(topology: inout Topology) {
  func createHydrogen(
    atomID: UInt32,
    orbital: SIMD3<Float>
  ) -> Atom {
    let atom = topology.atoms[Int(atomID)]
    
    var bondLength = atom.element.covalentRadius
    bondLength += Element.hydrogen.covalentRadius
    
    let position = atom.position + bondLength * orbital
    return Atom(position: position, element: .hydrogen)
  }
  
  let orbitalLists = topology.nonbondingOrbitals()
  
  var insertedAtoms: [Atom] = []
  var insertedBonds: [SIMD2<UInt32>] = []
  for atomID in topology.atoms.indices {
    let orbitalList = orbitalLists[atomID]
    for orbital in orbitalList {
      let hydrogen = createHydrogen(
        atomID: UInt32(atomID),
        orbital: orbital)
      let hydrogenID = topology.atoms.count + insertedAtoms.count
      insertedAtoms.append(hydrogen)
      
      let bond = SIMD2(
        UInt32(atomID),
        UInt32(hydrogenID))
      insertedBonds.append(bond)
    }
  }
  topology.atoms += insertedAtoms
  topology.bonds += insertedBonds
}

func createTopology() -> Topology {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 10 * (h + k + l) }
    Material { .checkerboard(.carbon, .silicon) }
  }
  
  var reconstruction = Reconstruction()
  reconstruction.atoms = lattice.atoms
  reconstruction.material = .checkerboard(.silicon, .carbon)
  var topology = reconstruction.compile()
  passivate(topology: &topology)
  return topology
}
let topology = createTopology()

// MARK: - Drafting the Minimization

// Utility for logging quantities to the console.
struct Format {
  static func pad(_ x: String, to size: Int) -> String {
    var output = x
    while output.count < size {
      output = " " + output
    }
    return output
  }
  static func time<T: BinaryFloatingPoint>(_ x: T) -> String {
    let xInFs = Float(x) * 1e3
    var repr = String(format: "%.2f", xInFs) + " fs"
    repr = pad(repr, to: 9)
    return repr
  }
  static func energy(_ x: Double) -> String {
    var repr = String(format: "%.2f", x / 160.218) + " eV"
    repr = pad(repr, to: 13)
    return repr
  }
  static func force(_ x: Float) -> String {
    var repr = String(format: "%.2f", x) + " pN"
    repr = pad(repr, to: 13)
    return repr
  }
  static func distance(_ x: Float) -> String {
    var repr = String(format: "%.2f", x) + " nm"
    repr = pad(repr, to: 9)
    return repr
  }
}

/*
// Minimizes a structure with xTB.
func minimize(atoms: [Atom], anchorIDs: [UInt32] = []) -> [[Atom]] {
  var calculatorDesc = xTB_CalculatorDescriptor()
  calculatorDesc.atomicNumbers = atoms.map(\.atomicNumber)
  calculatorDesc.positions = atoms.map(\.position)
  calculatorDesc.hamiltonian = .tightBinding
  let calculator = xTB_Calculator(descriptor: calculatorDesc)
  
  var minimizationDesc = FIREMinimizationDescriptor()
  minimizationDesc.masses = atoms.map {
    if $0.atomicNumber == 1 {
      return Float(4.0 * MM4YgPerAmu)
    } else {
      return Float(12.011 * MM4YgPerAmu)
    }
  }
  minimizationDesc.positions = calculator.molecule.positions
  minimizationDesc.anchors = Set(anchorIDs)
  var minimization = FIREMinimization(descriptor: minimizationDesc)
  
  var frames: [[Atom]] = []
  func createFrame() -> [Atom] {
    var output: [Atom] = []
    for atomID in atoms.indices {
      var atom = atoms[atomID]
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

    let forces = calculator.molecule.forces
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
    
    if converged {
      frames.append(createFrame())
      break
    } else if trialID == 499 {
      print("failed to converge!")
    }
  }
  
  return frames
}
*/

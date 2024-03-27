// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  // MARK: - Initializing Geometry
  
  var descriptor = LonsdaleiteRodDescriptor()
  descriptor.atomicLayerCount = 1
  let lonsdaleiteRod = LonsdaleiteRod(descriptor: descriptor)
  
  // MARK: - Initializing xTB
  
  XTBLibrary.loadLibrary(
    path: "/opt/homebrew/Cellar/xtb/6.6.1/lib/libxtb.6.dylib")
  
  let env = xtb_newEnvironment()!
  let calc = xtb_newCalculator()!
  let res = xtb_newResults()!
  let mol = createMolecule(
    env: env, atoms: lonsdaleiteRod.topology.atoms, charge: 0, uhf: 0)
  initializeEnvironment(
    env: env, mol: mol, calc: calc, verbosityLevel: XTB_VERBOSITY_MUTED)
  updateMolecule(
    env: env, mol: mol, atoms: lonsdaleiteRod.topology.atoms)
  
  xtb_singlepoint(env, mol, calc, res)
  
  // Find the initial potential energy.
  var initialPotentialEnergy: Double = .zero
  xtb_getEnergy(env, res, &initialPotentialEnergy)
  guard xtb_checkEnvironment(env) == 0 else {
    fatalError("Environment is bad.")
  }
  initialPotentialEnergy *= 4360
  
  // MARK: - Molecular Dynamics Simulation
  
  var currentAtoms = lonsdaleiteRod.topology.atoms
  var velocities = [SIMD3<Float>](
    repeating: .zero, count: currentAtoms.count)
  let masses = createMasses(atoms: currentAtoms)
  
  for frameID in 0..<20 {
    print("frame:", frameID, terminator: " | ")
    
    // Perform the singlepoint and update the energy.
    updateMolecule(env: env, mol: mol, atoms: currentAtoms)
    xtb_singlepoint(env, mol, calc, res)
    
    // Determine the potential energy.
    var potentialEnergy: Double = .zero
    xtb_getEnergy(env, res, &potentialEnergy)
    guard xtb_checkEnvironment(env) == 0 else {
      fatalError("Environment is bad.")
    }
    potentialEnergy *= 4360
    //      let potentialEnergyChange = 4360 * Float(energy - startEnergy)
    //      print(4360 * energyChange, "zJ", terminator: " ")
    
    // Determine the kinetic energy.
    var kineticEnergy: Double = .zero
    for atomID in currentAtoms.indices {
      let mass = masses[atomID]
      let velocity = velocities[atomID]
      let energy = 0.5 * mass * (velocity * velocity).sum()
      kineticEnergy += Double(energy)
    }
    
    // Report the energy conservation to the console.
    let drift = (kineticEnergy + potentialEnergy) - initialPotentialEnergy
    print(
      "\(String(format: "%.1f", kineticEnergy)) zJ (kinetic)",
      terminator: " | ")
    print(
      "\(String(format: "%.1f", potentialEnergy)) zJ (potential)",
      terminator: " | ")
    print(
      "\(String(format: "%.1f", drift)) zJ (drift)",
      terminator: " | ")
    
    // Terminate the log statement with a newline.
    print()
    
    // Retrieve the forces.
    let forces = createForces(
      env: env, mol: mol, calc: calc, res: res,
      atomCount: currentAtoms.count)
    guard xtb_checkEnvironment(env) == 0 else {
      fatalError("Environment is bad.")
    }
    
    // Integrate over time with the velocity Verlet integrator.
    for atomID in currentAtoms.indices {
      var atom = currentAtoms[atomID]
      var velocity = velocities[atomID]
      let force = forces[atomID]
      let mass = masses[atomID]
      
      // Update the velocity.
      var momentum = velocity * mass
      momentum += 0.002 * force
      velocity = momentum / mass
      
      // Update the position.
      atom.position += velocity * 0.002
      
      // Save the atom's state to memory.
      currentAtoms[atomID] = atom
      velocities[atomID] = velocity
    }
  }
  
  exit(0)
}

// MARK: - Geometry

struct LonsdaleiteRodDescriptor {
  var atomicLayerCount: Int?
}

// A structure whose size can be systematically varied to benchmark
// simulation speed.
struct LonsdaleiteRod {
  var topology = Topology()
  
  init(descriptor: LonsdaleiteRodDescriptor) {
    createLattice(descriptor: descriptor)
    passivate()
  }
  
  mutating func createLattice(descriptor: LonsdaleiteRodDescriptor) {
    guard let atomicLayerCount = descriptor.atomicLayerCount else {
      fatalError("Descriptor not complete.")
    }
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      let dimensionL = Float((atomicLayerCount + 1) / 2)
      Bounds { 1 * h + 1 * h2k + dimensionL * l }
      Material { .elemental(.carbon) }
      
      if atomicLayerCount % 2 == 1 {
        Volume {
          Origin { (Float(atomicLayerCount) / 2 - 0.01) * l }
          Plane { l }
          Replace { .empty }
        }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  // Adds hydrogens and sorts the atoms in Morton order.
  mutating func passivate() {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.carbon)
    reconstruction.topology = topology
    reconstruction.removePathologicalAtoms()
    reconstruction.createBulkAtomBonds()
    reconstruction.createHydrogenSites()
    reconstruction.resolveCollisions()
    reconstruction.createHydrogenBonds()
    topology = reconstruction.topology
    topology.sort()
  }
}

// MARK: - Utility Functions

// Requires that the environment is already created.
// - Accepts atom positions in nm.
func createMolecule(
  env: xtb_TEnvironment,
  atoms: [Entity],
  charge: Float,
  uhf: Int
) -> xtb_TMolecule {
  var atomTypes: [Int32] = []
  var coordinates: [Double] = []
  for atom in atoms {
    atomTypes.append(Int32(atom.storage.w))
    coordinates.append(Double(atom.position.x))
    coordinates.append(Double(atom.position.y))
    coordinates.append(Double(atom.position.z))
  }
  
  // https://en.wikipedia.org/wiki/Atomic_units
  let mPerBohr: Double = 5.29177210903e-11
  let nmPerM: Double = 1e9
  let conversionFactor = 1 / (mPerBohr * nmPerM)
  coordinates = coordinates.map {
    $0 * conversionFactor
  }
  
  var _natoms = Int32(atoms.count)
  var _charge = Double(charge)
  var _uhf = Int32(uhf)
  let output = xtb_newMolecule(
    env, &_natoms, &atomTypes, &coordinates,
    &_charge, &_uhf, nil, nil)
  if xtb_checkEnvironment(env) != 0 {
    fatalError("Call xtb_showEnvironment.")
  }
  
  guard let output else {
    fatalError("Failed to create molecule from atoms: \(atoms)")
  }
  return output
}

// Requires that the molecule is already created.
// - Accepts atom positions in nm.
func updateMolecule(
  env: xtb_TEnvironment,
  mol: xtb_TMolecule,
  atoms: [Entity]
) {
  var coordinates: [Double] = []
  for atom in atoms {
    coordinates.append(Double(atom.position.x))
    coordinates.append(Double(atom.position.y))
    coordinates.append(Double(atom.position.z))
  }
  
  // https://en.wikipedia.org/wiki/Atomic_units
  let mPerBohr: Double = 5.29177210903e-11
  let nmPerM: Double = 1e9
  let conversionFactor = 1 / (mPerBohr * nmPerM)
  coordinates = coordinates.map {
    $0 * conversionFactor
  }
  
  xtb_updateMolecule(env, mol, &coordinates, nil)
  if xtb_checkEnvironment(env) != 0 {
    fatalError("Call xtb_showEnvironment.")
  }
}

// Requires that the environment is already created.
func initializeEnvironment(
  env: xtb_TEnvironment,
  mol: xtb_TMolecule,
  calc: xtb_TCalculator,
  verbosityLevel: Int32 = XTB_VERBOSITY_MUTED
) {
  xtb_setVerbosity(env, verbosityLevel)
  if xtb_checkEnvironment(env) != 0 {
    fatalError("Call xtb_showEnvironment.")
  }
  
  xtb_loadGFN2xTB(env, mol, calc, nil)
  if xtb_checkEnvironment(env) != 0 {
    fatalError("Call xtb_showEnvironment.")
  }
}

// Requires that GFN2-xTB is already loaded.
// - Outputs forces in pN.
func createForces(
  env: xtb_TEnvironment,
  mol: xtb_TMolecule,
  calc: xtb_TCalculator,
  res: xtb_TResults,
  atomCount: Int
) -> [SIMD3<Float>] {
  xtb_singlepoint(env, mol, calc, res)
  if xtb_checkEnvironment(env) != 0 {
    fatalError("Call xtb_showEnvironment.")
  }
  
  var gradient = [Double](repeating: 0, count: atomCount * 3)
  xtb_getGradient(env, res, &gradient)
  if xtb_checkEnvironment(env) != 0 {
    fatalError("Call xtb_showEnvironment.")
  }
  
  // https://en.wikipedia.org/wiki/Atomic_units
  let NPerHaPerBohr: Double = 8.2387234983e-8
  let pNPerN: Double = 1e12
  let conversionFactor = NPerHaPerBohr * pNPerN
  
  var output: [SIMD3<Float>] = []
  for atomID in 0..<atomCount {
    let x = gradient[atomID * 3 + 0]
    let y = gradient[atomID * 3 + 1]
    let z = gradient[atomID * 3 + 2]
    var xyz = SIMD3<Double>(x, y, z)
    xyz *= conversionFactor
    
    // Force is the negative gradient.
    xyz = -xyz
    output.append(SIMD3<Float>(xyz))
  }
  return output
}

// Requires that the elements are recognized by the switch block.
func createMasses(atoms: [Entity]) -> [Float] {
  let conversionFactor: Double = MM4YgPerAmu
  
  var output: [Float] = []
  for atom in atoms {
    var mass: Float = .zero
    switch atom.atomicNumber {
    case 1: mass = 1.008
    case 6: mass = 12.011
    case 7: mass = 14.007
    case 8: mass = 15.999
    case 9: mass = 18.9984031636
    case 14: mass = 28.085
    case 15: mass = 30.9737619985
    case 16: mass = 32.06
    case 32: mass = 72.6308
    case 50: mass = 118.7100
    default:
      fatalError("Unrecognized atomic number: \(atom.atomicNumber)")
    }
    mass *= Float(conversionFactor)
    output.append(mass)
  }
  return output
}

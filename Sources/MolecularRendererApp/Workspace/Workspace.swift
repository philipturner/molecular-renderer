import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Goal: Build sequence for a lonsdaleite unit cell, in a matter of weeks.

// TODO: Can the carbene group successfully transfer from the tinCarbene tripod
// to the germaniumRadical tripod? From the tin tripod to the AFM probe with a
// germanium tip? What about leaving it partially activated (with a different
// halogen that will be activated at a different wavelength)? Then, covering
// the tripods with a thin shield to protect them from the UV light.

// TODO: You can just mount the Ge tripod on the AFM probe, instead of building
// a sharpened silicon lattice. That makes it much more viable within the
// limited amount of time to present the project.

func createGeometry() -> [[Entity]] {
  // Use the hydrogen transfer between Sn and Ge as a simpler test case, for
  // troubleshooting the other components of the simulation.
  // - After getting GFN2-xTB to work, try a GFN-FF ONIOM simulation that
  //   excludes the reactive moieties from GFN-FF. If the reaction runs
  //   correctly, GFN-FF should not throw a fit.
  //
  // TODO: Run a simulation of hydrogen transfer. Figure out how to do
  // velocities, and shift between local and global reference frames.
  let tinTripodSource = TripodCache.tinSet.hydrogen
  let germaniumTripodSource = TripodCache.germaniumSet.radical
  let tinTripod = Tripod(atoms: tinTripodSource)
  var germaniumTripod = Tripod(atoms: germaniumTripodSource)
  
  
  
  germaniumTripod.project(distance: 2.00)
  
  var initialAtoms: [Entity] = []
  initialAtoms += tinTripod.tooltip.createFrame()
  initialAtoms += tinTripod.feedstockAtoms
  initialAtoms += germaniumTripod.tooltip.createFrame()
  
  // Create the resource objects.
  let env = xtb_newEnvironment()!
  let calc = xtb_newCalculator()!
  let res = xtb_newResults()!
  let mol = createMolecule(
    env: env, atoms: initialAtoms, charge: 0, uhf: 0)
  initializeEnvironment(
    env: env, mol: mol, calc: calc, verbosityLevel: XTB_VERBOSITY_MINIMAL)
  updateMolecule(
    env: env, mol: mol, atoms: initialAtoms)
  
  // Start with 30 frames of no motion, to let the potential energy fizzle out.
  // There is 95% velocity damping per frame, so 21% * 21% of the kinetic
  // energy remains after 30 frames.
  var relativeVelocities = [SIMD3<Float>](
    repeating: .zero, count: initialAtoms.count)
  var frames: [[Entity]] = [initialAtoms]
  
  
  return [initialAtoms]
}

// MARK: - xTB Simulation Utilities

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

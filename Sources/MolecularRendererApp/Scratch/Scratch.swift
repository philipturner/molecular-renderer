// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

// For profiling; there are alternative methods on Windows.
import QuartzCore

func createGeometry() -> [Entity] {
  // MARK: - Initializing Geometry
  
  setenv("OMP_STACKSIZE", "2G", 1)
  
  var descriptor = LonsdaleiteRodDescriptor()
  descriptor.atomicLayerCount = 3
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
    env: env, mol: mol, calc: calc, verbosityLevel: XTB_VERBOSITY_FULL)
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
  
  var singlepointTimes: [Double] = []
  var gradientTimes: [Double] = []
  
  for frameID in 0..<1 {
    // Perform the singlepoint calculation.
    updateMolecule(env: env, mol: mol, atoms: currentAtoms)
    do {
      let start = CACurrentMediaTime()
      xtb_singlepoint(env, mol, calc, res)
      let end = CACurrentMediaTime()
      let elapsedTime = end - start
      
      // The very first frame is polluted by the initial singlepoint.
      if frameID > 0 {
        singlepointTimes.append(elapsedTime)
      }
    }
    
    // Retrieve the forces.
    var forces: [SIMD3<Float>]
    do {
      let start = CACurrentMediaTime()
      forces = createForces(
        env: env, mol: mol, calc: calc, res: res,
        atomCount: currentAtoms.count)
      let end = CACurrentMediaTime()
      let elapsedTime = end - start
      
      // The very first frame is polluted by the initial singlepoint.
      if frameID > 0 {
        gradientTimes.append(elapsedTime)
      }
    }
    guard xtb_checkEnvironment(env) == 0 else {
      fatalError("Environment is bad.")
    }
    
    // Determine the potential energy.
    var potentialEnergy: Double = .zero
    xtb_getEnergy(env, res, &potentialEnergy)
    guard xtb_checkEnvironment(env) == 0 else {
      fatalError("Environment is bad.")
    }
    potentialEnergy *= 4360
    
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
    print("frame:", frameID, terminator: " | ")
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
  
  func summarizeTimes(_ times: [Double]) {
    var minimum: Double = 1e38
    var accumulator: Double = .zero
    var maximum: Double = .zero
    
    for timeID in times.indices {
      let time = times[timeID]
      minimum = min(minimum, time)
      accumulator += time
      maximum = max(maximum, time)
    }
    let average = accumulator / Double(times.count)
    
    print("- maximum: \(Int(maximum * 1e6)) μs")
    print("- average: \(Int(average * 1e6)) μs")
    print("- minimum: \(Int(minimum * 1e6)) μs")
  }
  
  print()
  print("system size:")
  print("- atoms:", currentAtoms.count, terminator: " ")
  var carbonAtomCount: Int = .zero
  for atomID in currentAtoms.indices {
    let atom = currentAtoms[atomID]
    if atom.atomicNumber == 6 {
      carbonAtomCount += 1
    }
  }
  print("(\(carbonAtomCount) carbons)")
  
  var electronCount: Int = .zero
  for atomID in currentAtoms.indices {
    let atom = currentAtoms[atomID]
    electronCount += Int(atom.atomicNumber)
  }
  print("- electrons:", electronCount)
  print("- orbitals:", electronCount / 2)
  
  print()
  print("singlepoint latency:")
  summarizeTimes(singlepointTimes)
  
  print()
  print("gradient latency:")
  summarizeTimes(gradientTimes)
  
  // Report the linear algebra metric, GFLOPS/k.
  let n: Int = electronCount / 2
  let minLatency = singlepointTimes.min()!
  let mflopsK = Double(n * n * n) / Double(minLatency) / 1e6
  print()
  print("MFLOPS/k:", mflopsK, "* 2 * SCF iters")
  
  // The fastest samples typically had 6 self-consistent field iterations.
  //  24 orbitals | MFLOPS/k: 1.672308637821706 * 2 * SCF iters
  //  45 orbitals | MFLOPS/k: 2.850558771998712 * 2 * SCF iters
  //  66 orbitals | MFLOPS/k: 4.264920785466363 * 2 * SCF iters
  //  87 orbitals | MFLOPS/k: 6.719695497555669 * 2 * SCF iters
  // 108 orbitals | MFLOPS/k: 7.817894503753794 * 2 * SCF iters
  // 129 orbitals | MFLOPS/k: 7.040054789433814 * 2 * SCF iters
  // 150 orbitals | MFLOPS/k: 10.617432539617518 * 2 * SCF iters
  // 171 orbitals | MFLOPS/k: 11.824962467189183 * 2 * SCF iters
  // 192 orbitals | MFLOPS/k: 14.864456295740977 * 2 * SCF iters
  // 213 orbitals | MFLOPS/k: 16.72527140353499 * 2 * SCF iters
  // 234 orbitals | MFLOPS/k: 18.577699670110036 * 2 * SCF iters
  // 255 orbitals | MFLOPS/k: 21.400103087540572 * 2 * SCF iters
  // 276 orbitals | MFLOPS/k: 25.673197216320762 * 2 * SCF iters
  // 297 orbitals | MFLOPS/k: 26.257907112019282 * 2 * SCF iters
  // 318 orbitals | MFLOPS/k: 31.986542563476643 * 2 * SCF iters
  // 339 orbitals | MFLOPS/k: 34.261739645398904 * 2 * SCF iters
  // 360 orbitals | MFLOPS/k: 39.19743800150395 * 2 * SCF iters
  // 423 orbitals | MFLOPS/k: 50.09500766413211 * 2 * SCF iters
  // 528 orbitals | MFLOPS/k: 64.13679686045143 * 2 * SCF iters
  // 633 orbitals | MFLOPS/k: 83.85597804067446 * 2 * SCF iters
  // 738 orbitals | MFLOPS/k: 103.02688576953425 * 2 * SCF iters
  // 801 orbitals | MFLOPS/k: 111.85982029565841 * 2 * SCF iters
  // 822 orbitals | MFLOPS/k: 126.25993070649956 * 2 * SCF iters
  // Anything larger crashes at runtime.
  
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
  // WARNING: You must have already called xtb_singlepoint.
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

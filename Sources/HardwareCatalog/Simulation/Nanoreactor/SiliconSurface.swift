//
//  SiliconSurface.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 3/29/24.
//

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [[Entity]] {
  // MARK: - Initializing Geometry
  
  var surface = Surface()
  do {
    let atoms = surface.topology.atoms
    print("silicons:", atoms.filter { $0.atomicNumber == 14 }.count)
    print("hydrogens:", atoms.filter { $0.atomicNumber == 1 }.count)
    print("anchors:", surface.anchors.count)
  }
  
  // MARK: - Initializing xTB
  
  // Configure xTB for the highest performance possible without a custom
  // linear algebra library.
  setenv("OMP_STACKSIZE", "2G", 1)
  setenv("OMP_NUM_THREADS", "8", 1)
  XTBLibrary.loadLibrary(
    path: "/Users/philipturner/Documents/OpenMM/bypass_dependencies/libxtb.6.dylib")
  
  // Create the resource objects.
  let env = xtb_newEnvironment()!
  let calc = xtb_newCalculator()!
  let res = xtb_newResults()!
  let mol = createMolecule(
    env: env, atoms: surface.topology.atoms, charge: 0, uhf: 0)
  initializeEnvironment(
    env: env, mol: mol, calc: calc, verbosityLevel: XTB_VERBOSITY_MINIMAL)
  updateMolecule(
    env: env, mol: mol, atoms: surface.topology.atoms)
  
  // Begin the simulation at a high temperature.
  var velocities = [SIMD3<Float>](
    repeating: .zero, count: surface.topology.atoms.count)
  var finishedVelocities = 0
  while finishedVelocities < velocities.count {
    var direction = SIMD3<Float>.random(in: -1...1)
    let directionLength = (direction * direction).sum().squareRoot()
    if directionLength > 1 {
      continue
    } else {
      finishedVelocities += 1
    }
    
    direction /= directionLength
    let speed = 0.500 * Float.random(in: 0...2)
    let velocity = speed * direction
    velocities[finishedVelocities - 1] = velocity
  }
  
  // Create frames for rendering in the CAD program.
  var frames: [[Entity]] = []
  for frameID in 0...240 {
    if frameID == 0 {
      // Check that the structure is accepted.
      xtb_singlepoint(env, mol, calc, res)
      guard xtb_checkEnvironment(env) == 0 else {
        fatalError("Environment is bad.")
      }
      
      // Units: Hartree -> zJ
      var potentialEnergy: Double = .zero
      xtb_getEnergy(env, res, &potentialEnergy)
      potentialEnergy *= 4360
      let repr = String(format: "%.1f", potentialEnergy)
      print("initial potential energy:", repr, "zJ")
    } else {
      // Query the forces.
      let forces = createForces(
        env: env, mol: mol, calc: calc, res: res,
        atomCount: surface.topology.atoms.count)
      let masses = createMasses(atoms: surface.topology.atoms)
      
      // Perform one step of integration.
      for atomID in surface.topology.atoms.indices {
        var atom = surface.topology.atoms[atomID]
        var position = atom.position
        var velocity = velocities[atomID]
        let mass = masses[atomID]
        let force = forces[atomID]
        
        // Update the velocity.
        var momentum = velocity * mass
        momentum += 0.002 * force
        velocity = momentum / mass
        
        // Dampen the velocities, gradually tending toward the energy minimum.
        velocity *= 0.95
        
        // Clamp the velocities to something reasonable.
        let threshold: Float = 2.000
        velocity.replace(
          with: .init(repeating: -threshold),
          where: velocity .< -threshold)
        velocity.replace(
          with: .init(repeating: threshold),
          where: velocity .> threshold)
        
        // Update the position.
        position += velocity * 0.002
        
        // Save the state.
        if !surface.anchors.contains(UInt32(atomID)) {
          atom.position = position
          velocities[atomID] = velocity
          surface.topology.atoms[atomID] = atom
        }
      }
      
      // Update the resource objects for the next singlepoint.
      updateMolecule(env: env, mol: mol, atoms: surface.topology.atoms)
      
      // Check that total kinetic energy didn't explode.
      var maxForce: Float = .zero
      var kineticEnergy: Float = .zero
      for atomID in surface.topology.atoms.indices {
        // The force at the start of the current timestep.
        let force = forces[atomID]
        let forceMagnitude = (force * force).sum().squareRoot()
        if !surface.anchors.contains(UInt32(atomID)) {
          maxForce = max(maxForce, forceMagnitude)
        }
        
        // The kinetic energy at the end of the current timestep.
        let velocity = velocities[atomID]
        let mass = masses[atomID]
        kineticEnergy += 0.5 * mass * (velocity * velocity).sum()
      }
      print("maximum force:", maxForce, "pN")
      print("kinetic energy:", kineticEnergy, "zJ")
    }
    
    frames.append(surface.topology.atoms)
    print(frames.last![0].position)
  }
  
  return frames
}

// MARK: - Geometry

struct Surface {
  var topology = Topology()
  var anchors: Set<UInt32> = []
  
  init() {
    // Compile the geometry.
    createLattice()
    passivate()
    
    // Run through MM4.
    minimize()
    align()
    
    // Prepare to run through xTB.
    depassivate()
    createAnchors()
  }
  
  // Add the bulk silicon atoms.
  mutating func createLattice() {
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 2 * (h + k + l) }
      Material { .elemental(.silicon) }
      
      Volume {
        Origin { 1 * (h + k + l) }
        
        Convex {
          Origin { 0.5 * (h + k + l) }
          Plane { h + k + l }
        }
        Convex {
          Origin { -0.25 * (h + k + l) }
          Plane { -h - k - l }
        }
        
        var directions: [SIMD3<Float>] = []
        directions.append(h - k - l)
        directions.append(-h + k - l)
        directions.append(-h - k + l)
        
        for direction in directions {
          Convex {
            Origin { 0.5 * direction }
            Plane { direction }
          }
        }
        for direction in directions {
          Convex {
            Origin { -0.75 * direction }
            Plane { -direction }
          }
        }
        Replace { .empty }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  // Add hydrogens to the surfaces.
  mutating func passivate() {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.silicon)
    reconstruction.topology = topology
    reconstruction.removePathologicalAtoms()
    reconstruction.createBulkAtomBonds()
    reconstruction.createHydrogenSites()
    reconstruction.resolveCollisions()
    reconstruction.createHydrogenBonds()
    topology = reconstruction.topology
    topology.sort()
  }
  
  // Align the structure, so its principal axes align with the viewer.
  mutating func align() {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    let rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    
    let axesFP64 = rigidBody.principalAxes
    let axesFP32 = (SIMD3<Float>(axesFP64.0),
                    SIMD3<Float>(axesFP64.1),
                    SIMD3<Float>(axesFP64.2))
    let centerOfMass = SIMD3<Float>(rigidBody.centerOfMass)
    
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      var position = atom.position
      position -= centerOfMass
      position = SIMD3((position * axesFP32.2).sum(),
                       (position * axesFP32.1).sum(),
                       (position * axesFP32.0).sum())
      atom.position = position
      topology.atoms[atomID] = atom
    }
  }
  
  // Minimize the structure, assuming it's fully passivated.
  mutating func minimize() {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = parameters
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    forceField.positions = topology.atoms.map(\.position)
    forceField.minimize()
    
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      let position = forceField.positions[atomID]
      atom.position = position
      topology.atoms[atomID] = atom
    }
  }
  
  // Remove hydrogens from the surface.
  mutating func depassivate() {
    var removedAtoms: [UInt32] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      guard atom.atomicNumber == 1 else {
        continue
      }
      if atom.position.z > 0.22 {
        removedAtoms.append(UInt32(atomID))
      }
    }
    topology.remove(atoms: removedAtoms)
  }
  
  // Set the remaining hydrogens as anchors.
  mutating func createAnchors() {
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      guard atom.atomicNumber == 1 else {
        continue
      }
      anchors.insert(UInt32(atomID))
    }
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

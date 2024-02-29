//
//  Water.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/29/24.
//

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [[Entity]] {
  // After reproducing the tutorial, run an ab initio MD
  // simulation of water, starting at a 90° bond angle instead of the
  // correct angle. Reproduce the vibrational frequency from the
  // literature.
  //
  // Literature value:
  // 1594 cm^-1 (gas phase)
  // 2.99793e10 Hz / cm^-1
  // 21 femtoseconds per vibration
  //
  // Water appears to undergo two vibrations in 40 femtoseconds.
  // Therefore, the simulator is running correctly.
  XTBLibrary.loadLibrary(
    path: "/opt/homebrew/Cellar/xtb/6.6.1/lib/libxtb.6.dylib")
  
  var water = Water(angle: .pi / 2 * 100 / 90)
  let env = xtb_newEnvironment()!
  let calc = xtb_newCalculator()!
  let res = xtb_newResults()!
  let mol = createMolecule(
    env: env, atoms: water.atoms, charge: 0, uhf: 0)
  initializeEnvironment(env: env, mol: mol, calc: calc)
  updateMolecule(env: env, mol: mol, atoms: water.atoms)
  
  var output: [[Entity]] = []
  var momenta = [SIMD3<Float>](
    repeating: .zero, count: water.atoms.count)
  for frameID in 0...20 {
    print("frame:", frameID)
    
    if frameID > 0 {
      updateMolecule(env: env, mol: mol, atoms: water.atoms)
      
      let forces = createForces(
        env: env, mol: mol, calc: calc, res: res, atomCount: 3)
      for force in forces {
        print(force)
      }
      
      let masses = createMasses(atoms: water.atoms)
      for atomID in water.atoms.indices {
        print(atomID)
        print(water.atoms[atomID].position, momenta[atomID] / masses[atomID])
        momenta[atomID] += 0.002 * forces[atomID]
        
        let velocity = momenta[atomID] / masses[atomID]
        water.atoms[atomID].position += 0.002 * velocity
        print(water.atoms[atomID].position, velocity)
      }
    }
    
    // Each timestep is 2 fs.
    // 12 duplicated frames per timestep.
    // 10 timesteps per second.
    // 20 fs renders in 1 second.
    for _ in 0..<12 {
      output.append(water.atoms)
    }
  }
  
  return output
}

struct Water {
  var atoms: [Entity] = []
  
  // The angle must be in radians.
  init(angle: Float) {
    let oxygenPosition: SIMD3<Float> = .zero
    var hydrogenPosition1: SIMD3<Float> = [-1, 0, 0]
    var hydrogenPosition2: SIMD3<Float> = [
      -Float.cos(angle),
       Float.sin(angle),
       0
    ]
    
    // The O-H bond length is 0.957 Å, according to the literature.
    hydrogenPosition1 *= 0.957 / 10
    hydrogenPosition2 *= 0.957 / 10
    
    // Create atoms from the generated positions.
    let oxygen = Entity(
      position: oxygenPosition, type: .atom(.oxygen))
    let hydrogen1 = Entity(
      position: hydrogenPosition1, type: .atom(.hydrogen))
    let hydrogen2 = Entity(
      position: hydrogenPosition2, type: .atom(.hydrogen))
    atoms = [oxygen, hydrogen1, hydrogen2]
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
    default:
      fatalError("Unrecognized atomic number: \(atom.atomicNumber)")
    }
    mass *= Float(conversionFactor)
    output.append(mass)
  }
  return output
}

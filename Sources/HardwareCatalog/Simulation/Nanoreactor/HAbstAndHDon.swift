//
//  HAbstAndHDon.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/29/24.
//

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [[Entity]] {
  // MARK: - Scene Setup
  
  // HAbst1
  // - startSeparation = 0.80
  // - endSeparation = 0.55
  // - 16 seconds
  // HAbst2
  // - startSeparation = 0.90
  // - endSeparation = 0.65
  // - 34 seconds
  // HDon1
  // - startSeparation = 0.55
  // - endSeparation = 0.30
  // - 12 seconds
  // HDon2
  // - startSeparation = 0.60
  // - endSeparation = 0.35
  // - 12 seconds
  // HDon3
  // - startSeparation = 0.50
  // - endSeparation = 0.25
  // - 40 seconds
  // HDon4
  // - startSeparation = 0.65
  // - endSeparation = 0.40
  // - 34 seconds
  
  // Speed is in kilometers per second.
  let startSeparation: Float = 0.55
  let endSeparation: Float = 0.30
  let framesStationary: Int = 90
  let speed: Float = 2
  let simulating: Bool = true
  
  // Create a nanoreactor for HAbst and HDon reactions.
  var descriptor = IsobutaneDescriptor()
  descriptor.bulkElement = .carbon
  descriptor.tipElement = .carbon
  descriptor.passivation = .radical
  var leftHandSide = Isobutane(descriptor: descriptor)
  for i in leftHandSide.topology.atoms.indices {
    var atom = leftHandSide.topology.atoms[i]
    atom.position += SIMD3(-0.4, 0, 0)
    leftHandSide.topology.atoms[i] = atom
  }
  
  descriptor.bulkElement = .silicon
  descriptor.tipElement = .tin
  descriptor.passivation = .hydrogen
  var rightHandSide = Isobutane(descriptor: descriptor)
  for i in rightHandSide.topology.atoms.indices {
    var atom = rightHandSide.topology.atoms[i]
    atom.position.x = -atom.position.x
    atom.position += SIMD3(-0.4 + startSeparation, 0, 0)
    rightHandSide.topology.atoms[i] = atom
  }
  
  var isobutanes: [Isobutane] = []
  isobutanes.append(leftHandSide)
  isobutanes.append(rightHandSide)
  
  var isobutaneAtomVelocities: [[SIMD3<Float>]] = []
  isobutaneAtomVelocities.append(Array(
    repeating: .zero,
    count: leftHandSide.topology.atoms.count))
  isobutaneAtomVelocities.append(Array(
    repeating: [-speed, 0, 0],
    count: rightHandSide.topology.atoms.count))
  
  // MARK: - Simulator Setup
  
  XTBLibrary.loadLibrary(
    path: "/opt/homebrew/Cellar/xtb/6.6.1/lib/libxtb.6.dylib")
  
  let initialAtoms = isobutanes.flatMap(\.topology.atoms)
  let env = xtb_newEnvironment()!
  let calc = xtb_newCalculator()!
  let res = xtb_newResults()!
  let mol = createMolecule(
    env: env, atoms: initialAtoms, charge: 0, uhf: 1)
  initializeEnvironment(env: env, mol: mol, calc: calc)
  updateMolecule(env: env, mol: mol, atoms: initialAtoms)
  
  // MARK: - Simulation
  
  var output: [[Entity]] = []
  var movingBackward: Bool = false
  var stationaryStartFrame: Int = -1
  var currentIsobutaneVelocities: [SIMD3<Float>] = []
  currentIsobutaneVelocities.append(.zero)
  currentIsobutaneVelocities.append([-speed, 0, 0])
  for frameID in 0...300 {
    print("frame", frameID)
    
    if frameID > 0 {
      var forces: [SIMD3<Float>] = []
      var masses: [Float] = []
      if simulating {
        let currentAtoms = isobutanes.flatMap(\.topology.atoms)
        updateMolecule(env: env, mol: mol, atoms: currentAtoms)
        forces = createForces(
          env: env, mol: mol, calc: calc, res: res,
          atomCount: currentAtoms.count)
        masses = createMasses(atoms: currentAtoms)
        guard xtb_checkEnvironment(env) == 0 else {
          fatalError("Environment is bad.")
        }
      }
      
      var atomCursor: Int = .zero
      for isobutaneID in isobutanes.indices {
        var isobutane = isobutanes[isobutaneID]
        let targetPosition = -0.4 + endSeparation
        if isobutaneID == 1 {
          let frameDelta = frameID - stationaryStartFrame
          if !movingBackward {
            let tipAtomID = Int(isobutane.tipAtomID)
            let tipAtom = isobutane.topology.atoms[tipAtomID]
            if tipAtom.position.x < targetPosition {
              movingBackward = true
              stationaryStartFrame = frameID
              print("switched direction at frame \(frameID)")
              
              for i in isobutane.topology.atoms.indices {
                isobutaneAtomVelocities[isobutaneID][i] +=
                SIMD3(speed, 0, 0)
              }
              currentIsobutaneVelocities[1].x += speed
            }
          } else if frameDelta == framesStationary {
            for i in isobutane.topology.atoms.indices {
              isobutaneAtomVelocities[isobutaneID][i] +=
              SIMD3(speed, 0, 0)
            }
            currentIsobutaneVelocities[1].x += speed
          }
        }
        
        let bulkVelocity = currentIsobutaneVelocities[isobutaneID]
        let anchors = Set(isobutane.anchors)
        for i in isobutane.topology.atoms.indices {
          var atom = isobutane.topology.atoms[i]
          var velocity = isobutaneAtomVelocities[isobutaneID][i]
          
          if anchors.contains(UInt32(i)) {
            // Do not change the velocity.
          } else {
            if simulating {
              let force = forces[atomCursor]
              var momentum = velocity * masses[atomCursor]
              momentum += 0.002 * force
              velocity = momentum / masses[atomCursor]
              
              // Dampen the velocities to make the simulation more
              // numerically stable.
              var diff = velocity - bulkVelocity
              diff *= 0.95
              
              // Clamp the velocity to something reasonable.
              let threshold: Float = 4
              diff.replace(
                with: .init(repeating: -threshold),
                where: diff .< -threshold)
              diff.replace(
                with: .init(repeating: threshold),
                where: diff .> threshold)
              
              velocity = diff + bulkVelocity
            }
          }
          atom.position += velocity * 0.002
          
          isobutaneAtomVelocities[isobutaneID][i] = velocity
          isobutane.topology.atoms[i] = atom
          atomCursor += 1
        }
        isobutanes[isobutaneID] = isobutane
      }
    }
    
    output.append(isobutanes.flatMap(\.topology.atoms))
  }
  
  return output
}

enum Passivation {
  case acetyleneRadical
  case hydrogen
  case radical
}

struct IsobutaneDescriptor {
  var bulkElement: Element = .carbon
  var tipElement: Element = .carbon
  var passivation: Passivation = .hydrogen
}

struct Isobutane {
  var topology = Topology()
  var anchors: [UInt32] = []
  var tipAtomID: UInt32 = .max
  
  init(descriptor: IsobutaneDescriptor) {
    compilationPass0(bulkElement: descriptor.bulkElement)
    compilationPass1()
    compilationPass2(bulkElement: descriptor.bulkElement)
    compilationPass3(bulkElement: descriptor.bulkElement)
    compilationPass4(bulkElement: descriptor.bulkElement)
    compilationPass5(descriptor: descriptor)
    compilationPass6(tipElement: descriptor.tipElement)
  }
  
  // Create the center atoms.
  mutating func compilationPass0(bulkElement: Element) {
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 2 * (h + k + l) }
      Material { .elemental(bulkElement) }
      
      Volume {
        Convex {
          let direction = -h + k + l
          Origin { direction }
          Plane { -direction }
        }
        Convex {
          let direction = -h + k + l
          Origin { 1.2 * direction }
          Plane { direction }
        }
        Replace { .empty }
        
        // Mark the apex atom with lead. This will never be used as a bulk or
        // tip element.
        Convex {
          let direction = -h + k + l
          Origin { 1.05 * direction }
          Plane { direction }
        }
        Replace { .atom(.lead) }
      }
    }
    topology.atoms = lattice.atoms
  }
  
  // Rotate so the tip points right.
  mutating func compilationPass1() {
    var basisVector1: SIMD3<Float> = [-1, 1, 1]
    var basisVector2: SIMD3<Float> = [1, 0, 1]
    basisVector1 /= (basisVector1 * basisVector1).sum().squareRoot()
    basisVector2 /= (basisVector2 * basisVector2).sum().squareRoot()
    
    var basisVector3 = cross_platform_cross(basisVector1, basisVector2)
    basisVector3 /= (basisVector3 * basisVector3).sum().squareRoot()
    
    for atomID in topology.atoms.indices {
      var position = topology.atoms[atomID].position
      let xComponent = (position * basisVector1).sum()
      let zComponent = (position * basisVector2).sum()
      let yComponent = (position * basisVector3).sum()
      position = [xComponent, yComponent, zComponent]
      topology.atoms[atomID].position = position
    }
    
    // Adjust so the tip atom is the origin.
    var tipPosition: SIMD3<Float>?
    for atom in topology.atoms {
      if atom.atomicNumber == Element.lead.rawValue {
        tipPosition = atom.position
      }
    }
    for atomID in topology.atoms.indices {
      topology.atoms[atomID].position -= tipPosition!
    }
  }
  
  // Remove the pathological atoms.
  mutating func compilationPass2(bulkElement: Element) {
    let matches = topology.match(
      topology.atoms,
      algorithm: .absoluteRadius(bulkElement.covalentRadius * 2.2))
    
    var removedAtoms: [UInt32] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      for j in matches[i] where i < j {
        let bond = SIMD2(UInt32(i), UInt32(j))
        insertedBonds.append(bond)
      }
      if matches[i].count == 1 {
        removedAtoms.append(UInt32(i))
      }
    }
    topology.insert(bonds: insertedBonds)
    topology.remove(atoms: removedAtoms)
  }
  
  // Add the hydrogens pointing in the X direction.
  // - NOTE: This sets the anchor indices. It assumes the atoms at the
  //   beginning of the list won't change position.
  mutating func compilationPass3(bulkElement: Element) {
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      if atom.atomicNumber == Element.lead.rawValue {
        continue
      } else {
        let chBondLength = Self.hydrogenBondLength(element: bulkElement)
        let orbital: SIMD3<Float> = [-1, 0, 0]
        let position = atom.position + orbital * chBondLength
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        let bond = SIMD2(UInt32(atomID), UInt32(hydrogenID))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(bond)
        
        anchors.append(UInt32(hydrogenID))
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Add hydrogens to the sidewall atoms.
  mutating func compilationPass4(bulkElement: Element) {
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp3)
    
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      if atom.atomicNumber == Element.lead.rawValue {
        continue
      } else {
        for orbital in orbitals[atomID] {
          let chBondLength = Self.hydrogenBondLength(element: bulkElement)
          let position = atom.position + orbital * chBondLength
          let hydrogen = Entity(position: position, type: .atom(.hydrogen))
          
          let hydrogenID = topology.atoms.count + insertedAtoms.count
          let bond = SIMD2(UInt32(atomID), UInt32(hydrogenID))
          insertedAtoms.append(hydrogen)
          insertedBonds.append(bond)
        }
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Add the passivator.
  mutating func compilationPass5(descriptor: IsobutaneDescriptor) {
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      if atom.atomicNumber == Element.lead.rawValue {
        switch descriptor.passivation {
        case .acetyleneRadical:
          let xcBondLength = Self.acetyleneBondLength(
            element: descriptor.tipElement)
          let orbital1: SIMD3<Float> = [1, 0, 0]
          let position1 = atom.position + orbital1 * xcBondLength
          let carbon1 = Entity(position: position1, type: .atom(.carbon))
          
          let carbonID1 = topology.atoms.count + insertedAtoms.count
          let bond1 = SIMD2(UInt32(atomID), UInt32(carbonID1))
          insertedAtoms.append(carbon1)
          insertedBonds.append(bond1)
          
          let ccBondLength: Float = 1.2100 / 10
          let orbital2: SIMD3<Float> = [1, 0, 0]
          let position2 = position1 + orbital2 * ccBondLength
          let carbon2 = Entity(position: position2, type: .atom(.carbon))
          
          let carbonID2 = topology.atoms.count + insertedAtoms.count
          let bond2 = SIMD2(UInt32(carbonID1), UInt32(carbonID2))
          insertedAtoms.append(carbon2)
          insertedBonds.append(bond2)
        case .hydrogen:
          let xhBondLength = Self.hydrogenBondLength(
            element: descriptor.tipElement)
          let orbital: SIMD3<Float> = [1, 0, 0]
          let position = atom.position + orbital * xhBondLength
          let hydrogen = Entity(position: position, type: .atom(.hydrogen))
          
          let hydrogenID = topology.atoms.count + insertedAtoms.count
          let bond = SIMD2(UInt32(atomID), UInt32(hydrogenID))
          insertedAtoms.append(hydrogen)
          insertedBonds.append(bond)
        case .radical:
          break
        }
      } else {
        continue
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Transmute the lead marker into the tip element.
  mutating func compilationPass6(tipElement: Element) {
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      if atom.atomicNumber == Element.lead.rawValue {
        topology.atoms[atomID].atomicNumber = tipElement.rawValue
        self.tipAtomID = UInt32(atomID)
      }
    }
  }
}

extension Isobutane {
  // The bond length between an sp3 element and hydrogen.
  static func hydrogenBondLength(element: Element) -> Float {
    switch element {
    case .carbon:
      return 1.1120 / 10
    case .silicon:
      return 1.483 / 10
    case .germanium:
      return 1.529 / 10
    case .tin:
      return 1.6960 / 10
    default:
      fatalError("Unexpected element for X-H bond.")
    }
  }
  
  // The bond length between an sp3 element and sp1 carbon.
  static func acetyleneBondLength(element: Element) -> Float {
    switch element {
    case .carbon:
      return 1.4700 / 10
    case .silicon:
      let sp1sp2Difference: Float = 1.4700 - 1.4990
      return (1.8540 + sp1sp2Difference) / 10
    case .germanium:
      let sp1sp2Difference: Float = 1.4700 - 1.4990
      return (1.9350 + sp1sp2Difference) / 10
    case .tin:
      let sp1sp2Difference: Float = 1.4700 - 1.4990
      let snGeDifference: Float = 2.1470 - 1.9490
      return (1.9350 + sp1sp2Difference + snGeDifference) / 10
    default:
      fatalError("Unexpected element for X-CC bond.")
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

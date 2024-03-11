//
//  Methylation.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 3/2/24.
//

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [[Entity]] {
  // MARK: - Scene Setup
  
  // Methylene
  // - endSeparation = 0.35
  // - endSeparation = 0.33 (Methylene2T)
  // MethyleneGraphene
  // - endSeparation = 0.35
  // MethyleneSilicon
  // - endSeparation = 0.40
  // - endSeparation = 0.30 (MethyleneSilicon1)
  // Silylene
  // - endSeparation = 0.35
  
  // Speed is in kilometers per second.
  let speed: Float = 1
  let endSeparation: Float = 0.35
  let framesStationary: Int = 100
  let framesTotal: Int = 400
  
  let simulating: Bool = true
  let uhf: Int = 0
  
  // Make the tooltip approach from above. Orient the molecules vertically
  // instead of horizontally.
  let azimuthTilt = Quaternion<Float>(angle: 90 * .pi / 180, axis: [0, 1, 0])
  let startSeparation = endSeparation + 100 * 0.002 * speed
  
  var descriptor = TooltipDescriptor()
  descriptor.feedstock = .methylene
  descriptor.bridgehead = .silicon
  descriptor.sidewall = .carbon
  
  var tooltip = Tooltip(descriptor: descriptor)
  for i in tooltip.topology.atoms.indices {
    var atom = tooltip.topology.atoms[i]
    atom.position = SIMD3(atom.position.x, -atom.position.z, atom.position.y)
    atom.position.y += startSeparation - 0.4
    atom.position = azimuthTilt.act(on: atom.position)
    tooltip.topology.atoms[i] = atom
  }
  
  descriptor.feedstock = .radical
  descriptor.bridgehead = .carbon
  descriptor.sidewall = .carbon
  
  var workpiece = Graphene()
  for i in workpiece.topology.atoms.indices {
    var atom = workpiece.topology.atoms[i]
    atom.position = SIMD3(atom.position.x, atom.position.z, atom.position.y)
    atom.position.y += -0.4
    atom.position = azimuthTilt.act(on: atom.position)
    workpiece.topology.atoms[i] = atom
  }
  
  // MARK: - Simulation Setup
  
  XTBLibrary.loadLibrary(
    path: "/opt/homebrew/Cellar/xtb/6.6.1/lib/libxtb.6.dylib")
  
  let initialAtoms = tooltip.topology.atoms + workpiece.topology.atoms
  let env = xtb_newEnvironment()!
  let calc = xtb_newCalculator()!
  let res = xtb_newResults()!
  let mol = createMolecule(
    env: env, atoms: initialAtoms, charge: 0, uhf: uhf)
  initializeEnvironment(env: env, mol: mol, calc: calc)
  updateMolecule(env: env, mol: mol, atoms: initialAtoms)
  
  xtb_singlepoint(env, mol, calc, res)
  var startEnergy: Double = .zero
  xtb_getEnergy(env, res, &startEnergy)
  guard xtb_checkEnvironment(env) == 0 else {
    fatalError("Environment is bad.")
  }
  
  var tooltipBulkVelocity = SIMD3<Float>(0, -speed, 0)
  var tooltipAtomVelocities = [SIMD3<Float>](
    repeating: tooltipBulkVelocity, count: tooltip.topology.atoms.count)
  var workpieceAtomVelocities = [SIMD3<Float>](
    repeating: .zero, count: workpiece.topology.atoms.count)
  
  var output: [[Entity]] = []
  var movingBackward: Bool = false
  var stationaryStartFrame: Int = -1
  
  for frameID in 0...framesTotal {
    print("\nframe", frameID, terminator: " ")
    
    if frameID > 0 {
      var forces: [SIMD3<Float>] = []
      var masses: [Float] = []
      if simulating {
        let currentAtoms = tooltip.topology.atoms + workpiece.topology.atoms
        updateMolecule(env: env, mol: mol, atoms: currentAtoms)
        xtb_singlepoint(env, mol, calc, res)
        
        var energy: Double = .zero
        xtb_getEnergy(env, res, &energy)
        guard xtb_checkEnvironment(env) == 0 else {
          fatalError("Environment is bad.")
        }
        let energyChange = Float(energy - startEnergy)
        print(4360 * energyChange, "zJ", terminator: " ")
        
        forces = createForces(
          env: env, mol: mol, calc: calc, res: res,
          atomCount: currentAtoms.count)
        masses = createMasses(atoms: currentAtoms)
        guard xtb_checkEnvironment(env) == 0 else {
          fatalError("Environment is bad.")
        }
      }
      
      let targetPosition = -0.4 + endSeparation
      let frameDelta = frameID - stationaryStartFrame
      if !movingBackward {
        let tipAtomID = Int(tooltip.tipAtomID)
        let tipAtom = tooltip.topology.atoms[tipAtomID]
        if tipAtom.position.y < targetPosition {
          movingBackward = true
          stationaryStartFrame = frameID
          for i in tooltip.topology.atoms.indices {
            tooltipAtomVelocities[i] += SIMD3(0, speed, 0)
          }
          tooltipBulkVelocity += SIMD3(0, speed, 0)
        }
      } else if frameDelta == framesStationary {
        for i in tooltip.topology.atoms.indices {
          tooltipAtomVelocities[i] += SIMD3(0, speed, 0)
        }
        tooltipBulkVelocity += SIMD3(0, speed, 0)
      }
      
      var atomCursor: Int = .zero
      func integrate(
        topology: inout Topology,
        velocities: inout [SIMD3<Float>],
        bulkVelocity: SIMD3<Float>,
        anchors: Set<UInt32>
      ) {
        for i in topology.atoms.indices {
          var atom = topology.atoms[i]
          var velocity = velocities[i]
          
          if anchors.contains(UInt32(i)) {
            // Do not change the velocity.
          } else if simulating {
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
          atom.position += velocity * 0.002
          
          velocities[i] = velocity
          topology.atoms[i] = atom
          atomCursor += 1
        }
      }
      
      integrate(
        topology: &tooltip.topology,
        velocities: &tooltipAtomVelocities,
        bulkVelocity: tooltipBulkVelocity,
        anchors: tooltip.anchors)
      integrate(
        topology: &workpiece.topology,
        velocities: &workpieceAtomVelocities,
        bulkVelocity: .zero,
        anchors: workpiece.anchors)
    }
    
    output.append(tooltip.topology.atoms + workpiece.topology.atoms)
  }
  print()
  
  return output
}

// MARK: - Structures

enum Feedstock {
  case radical
  case methylene
  case silylene
}

struct TooltipDescriptor {
  var feedstock: Feedstock?
  var bridgehead: Element?
  var sidewall: Element?
}

// A tooltip pointing toward the Z direction.
struct Tooltip {
  var topology = Topology()
  var anchors: Set<UInt32> = []
  var tipAtomID: UInt32 = .max
  
  init(descriptor: TooltipDescriptor) {
    guard descriptor.feedstock != nil,
          descriptor.bridgehead != nil,
          descriptor.sidewall != nil else {
      fatalError("Descriptor not complete.")
    }
    
    createBaseAtoms(descriptor: descriptor)
    createSidewallHydrogens()
    createFeedstock(descriptor: descriptor)
  }
  
  mutating func createBaseAtoms(descriptor: TooltipDescriptor) {
    let tipAtom = Entity(position: .zero, type: .atom(descriptor.bridgehead!))
    topology.insert(atoms: [tipAtom])
    tipAtomID = 0
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for sidewallID in 0..<3 {
      let angle = Float(sidewallID) * (2 * .pi) / 3
      let rotation1 = Quaternion<Float>(
        angle: 109.47 * .pi / 180, axis: [-1, 0, 0])
      let rotation2 = Quaternion<Float>(
        angle: angle, axis: [0, 0, 1])
      
      var orbital: SIMD3<Float> = [0, 0, 1]
      orbital = rotation1.act(on: orbital)
      orbital = rotation2.act(on: orbital)
      
      var hydrogen: Entity
      switch descriptor.sidewall! {
      case .hydrogen:
        let xhBondLength = Tooltip.hydrogenBondLength(
          element: descriptor.bridgehead!)
        let position = tipAtom.position + xhBondLength * orbital
        hydrogen = Entity(position: position, type: .atom(.hydrogen))
        
        let bond = SIMD2(UInt32(0), UInt32(topology.atoms.count - 1))
        insertedBonds.append(bond)
      case .carbon, .silicon:
        var position1: SIMD3<Float>
        if descriptor.sidewall! == .carbon {
          let xcBondLength = Tooltip.carbonBondLength(
            element: descriptor.bridgehead!)
          position1 = tipAtom.position + xcBondLength * orbital
          let carbon = Entity(position: position1, type: .atom(.carbon))
          topology.insert(atoms: [carbon])
        } else {
          let xSiBondLength = Tooltip.siliconBondLength(
            element: descriptor.bridgehead!)
          position1 = tipAtom.position + xSiBondLength * orbital
          let silicon = Entity(position: position1, type: .atom(.silicon))
          topology.insert(atoms: [silicon])
        }
        
        let chBondLength = Tooltip.hydrogenBondLength(
          element: descriptor.sidewall!)
        let position2 = position1 + chBondLength * SIMD3<Float>(0, 0, -1)
        hydrogen = Entity(position: position2, type: .atom(.hydrogen))
        
        let bond1 = SIMD2(UInt32(0), UInt32(topology.atoms.count - 1))
        let bond2 = SIMD2(bond1[1], UInt32(topology.atoms.count))
        insertedBonds.append(bond1)
        insertedBonds.append(bond2)
      default:
        fatalError("Unsupported sidewall element.")
      }
      
      let hydrogenID = UInt32(topology.atoms.count)
      anchors.insert(hydrogenID)
      topology.insert(atoms: [hydrogen])
    }
    topology.insert(bonds: insertedBonds)
  }
  
  mutating func createSidewallHydrogens() {
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp3)
    
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      guard orbitals[atomID].count == 2 else {
        continue
      }
      let atom = topology.atoms[atomID]
      let element = Element(atom.atomicNumber)
      
      for orbital in orbitals[atomID] {
        let xhBondLength = Tooltip.hydrogenBondLength(element: element)
        let position = atom.position + xhBondLength * orbital
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        let bond = SIMD2(UInt32(atomID), UInt32(hydrogenID))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(bond)
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  mutating func createFeedstock(descriptor: TooltipDescriptor) {
    let feedstock = descriptor.feedstock!
    if feedstock == .radical {
      return
    }
    
    var feedstockElement: Element
    var feedstockHBondLength: Float
    var feedstockTipBondLength: Float
    if feedstock == .methylene {
      feedstockElement = .carbon
      feedstockHBondLength = 1.1010 / 10
      feedstockTipBondLength = Self.methyleneBondLength(
        element: descriptor.bridgehead!)
    } else {
      feedstockElement = .silicon
      feedstockHBondLength = Self.hydrogenBondLength(element: .silicon)
      feedstockTipBondLength = Self.siliconBondLength(
        element: descriptor.bridgehead!)
    }
    
    // Add the carbon or silicon atom.
    var centerAtomPosition: SIMD3<Float>
    var centerAtomID: Int
    do {
      let orbital: SIMD3<Float> = [0, 0, 1]
      let position = SIMD3<Float>.zero + feedstockTipBondLength * orbital
      let atom = Entity(position: position, type: .atom(feedstockElement))
      let bond = SIMD2(UInt32(0), UInt32(topology.atoms.count))
      centerAtomPosition = position
      centerAtomID = topology.atoms.count
      topology.insert(atoms: [atom])
      topology.insert(bonds: [bond])
    }
    
    var angle1: Float
    var angle2: Float
    if feedstock == .methylene {
      angle1 = 120
      angle2 = 180
    } else {
      angle1 = 109.47
      angle2 = 120
    }
    angle1 *= .pi / 180
    angle2 *= .pi / 180
    
    let rotation1 = Quaternion<Float>(angle: angle1, axis: [0, 1, 0])
    let orbital1 = rotation1.act(on: [0, 0, -1])
    let position1 = centerAtomPosition + feedstockHBondLength * orbital1
    
    let rotation2 = Quaternion<Float>(angle: angle2, axis: [0, 0, 1])
    let orbital2 = rotation2.act(on: orbital1)
    let position2 = centerAtomPosition + feedstockHBondLength * orbital2
    
    for position in [position1, position2] {
      let hydrogen = Entity(position: position, type: .atom(.hydrogen))
      let hydrogenID = topology.atoms.count
      let bond = SIMD2(UInt32(centerAtomID), UInt32(hydrogenID))
      topology.insert(atoms: [hydrogen])
      topology.insert(bonds: [bond])
    }
  }
}

extension Tooltip {
  // The bond length between an sp3 element and hydrogen.
  // - This is not correct for methylene.
  // - This is correct for silylene.
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
  
  // The bond length between an sp3 element and sp2 carbon.
  static func methyleneBondLength(element: Element) -> Float {
    switch element {
    case .carbon:
      return 1.4990 / 10
    case .silicon:
      return 1.8540 / 10
    case .germanium:
      return 1.9350 / 10
    case .tin:
      let snGeDifference: Float = 2.1470 - 1.9490
      return (1.9350 + snGeDifference) / 10
    default:
      fatalError("Unexpected element for X-CH2* bond.")
    }
  }
  
  // The bond length between an sp3 element and sp3 carbon.
  static func carbonBondLength(element: Element) -> Float {
    switch element {
    case .carbon:
      return 1.5270 / 10
    case .silicon:
      return 1.876 / 10
    case .germanium:
      return 1.949 / 10
    case .tin:
      return 2.1470 / 10
    default:
      fatalError("Unexpected element for X-CH3 bond.")
    }
  }
  
  // The bond length between an sp3 element and sp3 silicon.
  // - Use this for silylene as well.
  static func siliconBondLength(element: Element) -> Float {
    switch element {
    case .carbon:
      return 1.876 / 10
    case .silicon:
      return 2.322 / 10
    case .germanium:
      // Source:
      // https://www.degruyter.com/document/doi/10.1515/MGMC.1999.22.6.385/pdf
      return 2.372 / 10
    case .tin:
      // Source:
      // https://www.degruyter.com/document/doi/10.1515/MGMC.1999.22.6.385/pdf
      return 2.610 / 10
    default:
      fatalError("Unexpected element for X-SiH3 bond.")
    }
  }
}

// A graphene flake whose normal is the Z direction.
struct Graphene {
  var topology = Topology()
  var anchors: Set<UInt32> = []
  
  init() {
    let lattice = createLattice()
    topology.insert(atoms: lattice.atoms)
    
    adjustLatticeAtoms()
    removeCenterMarker()
    addHydrogens()
    removeAnchorMarkers()
  }
  
  mutating func createLattice() -> Lattice<Hexagonal> {
    Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 2 * h + 2 * h2k + 1 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Convex {
          Origin { 0.3 * l }
          Plane { l }
        }
        Convex {
          Origin { 1 * h + 1.75 * h2k }
          Plane { k - h }
          Plane { k + 2 * h }
        }
        Convex {
          Origin { 1.5 * h2k }
          Plane { h2k }
        }
        Replace { .empty }
      }
      
      Volume {
        Origin { h + 0.8 * h2k }
        Concave {
          var directions: [SIMD3<Float>] = []
          directions.append(h)
          directions.append(h2k)
          directions.append(-h)
          directions.append(-h2k)
          for direction in directions {
            Convex {
              Origin { 0.3 * direction }
              Plane { -direction }
            }
          }
        }
        Replace { .atom(.gold) }
      }
      
      Volume {
        Origin { h + 0.625 * h2k }
        
        var directions: [SIMD3<Float>] = []
        directions.append(h2k)
        directions.append(-k + h)
        directions.append(-k - 2 * h)
        for direction in directions {
          Convex {
            Origin { 0.55 * direction }
            Plane { direction }
          }
        }
        Replace { .atom(.silicon) }
      }
    }
  }
  
  // Center the lattice at the origin, and scale it to the graphene lattice
  // constant.
  mutating func adjustLatticeAtoms() {
    var goldPosition: SIMD3<Float>?
    for atom in topology.atoms {
      if atom.atomicNumber == 79 {
        goldPosition = atom.position
      }
    }
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      atom.position -= goldPosition!
      atom.position.z = 0
      topology.atoms[atomID] = atom
    }
    
    let grapheneConstant: Float = 2.45 / 10
    let lonsdaleiteConstant = Constant(.hexagon) { .elemental(.carbon) }
    let scaleFactor = grapheneConstant / lonsdaleiteConstant
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      atom.position *= scaleFactor
      topology.atoms[atomID] = atom
    }
  }
  
  // Transmute the gold atom to carbon.
  mutating func removeCenterMarker() {
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      if atom.atomicNumber == 79 {
        atom.atomicNumber = 6
      }
      topology.atoms[atomID] = atom
    }
  }
  
  // Add hydrogens to the perimeter of the graphene flake.
  mutating func addHydrogens() {
    let searchRadius = 2.1 * Element.carbon.covalentRadius
    let matches = topology.match(
      topology.atoms, algorithm: .absoluteRadius(searchRadius))
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in matches.indices {
      for j in matches[i] where i < j {
        let bond = SIMD2(UInt32(i), UInt32(j))
        insertedBonds.append(bond)
      }
    }
    topology.insert(bonds: insertedBonds)
    
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp2)
    var insertedAtoms: [Entity] = []
    insertedBonds = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      for orbital in orbitals[atomID] {
        // Source: MM4/TinkerParameters
        let chBondLength: Float = 1.1010 / 10
        let position = atom.position + chBondLength * orbital
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        let bond = SIMD2(UInt32(atomID), UInt32(hydrogenID))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(bond)
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Mark the anchors and transmute the silicon atoms to carbon.
  mutating func removeAnchorMarkers() {
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    for atomID in topology.atoms.indices {
      let map = atomsToAtomsMap[atomID]
      if map.count == 1 {
        let otherID = Int(map[0])
        let otherAtom = topology.atoms[otherID]
        if otherAtom.atomicNumber == 14 {
          anchors.insert(UInt32(atomID))
        }
      }
    }
    
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      if atom.atomicNumber == 14 {
        atom.atomicNumber = 6
      }
      topology.atoms[atomID] = atom
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

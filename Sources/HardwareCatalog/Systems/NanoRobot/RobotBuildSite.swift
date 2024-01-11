//
//  RobotBuildSite.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/11/24.
//

import HDL
import MM4
import OpenMM
import QuaternionModule

// The scene that the robot fingers act on. It is different in each of the two
// videos. Two parts:
// - 'RobotBuildPlate', the anchored floor/plate.
// - 'RobotMolecule', the piece the robot picks up.

// struct RobotBuiltSite
// - struct RobotBuildPlate
// - struct RobotBuildMolecule

struct RobotBuildPlate {
  var topology = Topology()
  // eventually an MM4RigidBody?
  
  init(video: RobotVideo) {
    if video == .version1 {
      compilationPass0(boundsH: 18)
    } else if video == .version2 {
      compilationPass0(boundsH: 36)
      compilationPass1()
      compilationPass2()
      
      // Break ground with MM4ForceField by minimizing the colliding hydrogens
      // in this structure (compilation pass 4).
      compilationPass3()
      compilationPass4()
    }
  }
  
  mutating func compilationPass0(boundsH: Float) {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { boundsH * h + 9 * h2k + 4 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Convex {
          Origin { 0.5 * l }
          Plane { -l }
        }
        Convex {
          Origin { 1.25 * l }
          Plane { l }
        }
        Convex {
          Origin { 0.5 * h }
          Plane { -h }
        }
        
        Replace { .empty }
      }
    }
    var atoms = lattice.atoms
    
    for i in atoms.indices {
      var position = atoms[i].position
      position = SIMD3(position.x, position.z, position.y)
      atoms[i].position = position
    }
    topology.insert(atoms: atoms)
  }
  
  mutating func compilationPass1() {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 16 * h + 16 * h2k + 3 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 8 * h + 8 * h2k }
        
        var directions: [SIMD3<Float>] = []
        directions.append(h + k / 2)
        directions.append(h / 2 + k)
        directions.append(-h / 2 + k / 2)
        directions.append(contentsOf: directions.map(-))
        
        var offsets: [SIMD3<Float>] = []
        offsets.append(0.75 * (h + k))
        offsets.append(0.75 * (h + k))
        offsets.append(.zero)
        offsets.append(.zero)
        offsets.append(.zero)
        offsets.append(0.75 * (h + k))
        
        for (direction, offset) in zip(directions, offsets) {
          Convex {
            Origin { 6 * direction + offset }
            Plane { direction }
          }
        }
        Concave {
          for (direction, offset) in zip(directions, offsets) {
            Convex {
              Origin { 4 * direction + offset }
              Plane { -direction }
            }
          }
        }
        
        Replace { .empty }
      }
    }
    var atoms = lattice.atoms
    
    var h = SIMD3<Float>(1, 0, 0)
    var k = SIMD3<Float>(-1.0 / 2, Float(3.0 / 4).squareRoot(), 0)
    var l = SIMD3<Float>(0, 0, 1)
    h *= Constant(.hexagon) { .elemental(.carbon) }
    k *= Constant(.hexagon) { .elemental(.carbon) }
    l *= Constant(.prism) { .elemental(.carbon) }
    
    for i in atoms.indices {
      let h2k = h + 2 * k
      atoms[i].position.y = -atoms[i].position.y
      atoms[i].position += 20 * h + 13 * h2k + 1.5 * l
    }
    
    for i in atoms.indices {
      var position = atoms[i].position
      position = SIMD3(position.x, position.z, position.y)
      atoms[i].position = position
    }
    topology.insert(atoms: atoms)
  }
  
  mutating func compilationPass2() {
    let matches = topology.match(topology.atoms)
    
    var bonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      for j in matches[i] where i < j {
        bonds.append(SIMD2(UInt32(i), j))
      }
    }
    topology.insert(bonds: bonds)
    
    let orbitals = topology.nonbondingOrbitals()
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    let chBondLength = Element.carbon.covalentRadius +
    Element.hydrogen.covalentRadius
    
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      let carbon = topology.atoms[i]
      func addOrbital(_ orbital: SIMD3<Float>) {
        let position = carbon.position + orbital * chBondLength
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        let hydrogenID = UInt32(topology.atoms.count + insertedAtoms.count)
        insertedAtoms.append(hydrogen)
        insertedBonds.append(SIMD2(UInt32(i), hydrogenID))
      }
      for orbital in orbitals[i] {
        addOrbital(orbital)
      }
      
      // Patch the primary carbons so we keep the same atom count as in the
      // video.
      let neighbors = atomsToAtomsMap[i]
      if neighbors.count == 1 {
        // Generate an orbital for the 1 bond that exists.
        let neighbor = topology.atoms[Int(neighbors.first!)]
        var neighborOrbital = neighbor.position - carbon.position
        neighborOrbital /= (
          neighborOrbital * neighborOrbital).sum().squareRoot()
        
        // Generate an axis to rotate 109.5° around.
        let randomVector = SIMD3<Float>(-1, 0, 0)
        var axis = cross_platform_cross(neighborOrbital, randomVector)
        axis /= (axis * axis).sum().squareRoot()
        let rotation1 = Quaternion(angle: 109.47 * .pi / 180, axis: axis)
        let orbital1 = rotation1.act(on: neighborOrbital)
        addOrbital(orbital1)
        
        // Rotate 120° around the neighbor orbital for the other hydrogens.
        let rotation2 = Quaternion(angle: 2 * .pi / 3, axis: neighborOrbital)
        let orbital2 = rotation2.act(on: orbital1)
        let orbital3 = rotation2.act(on: orbital2)
        addOrbital(orbital2)
        addOrbital(orbital3)
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Sort the topology for better MD performance.
  mutating func compilationPass3() {
    topology.sort()
  }
  
  mutating func compilationPass4() {
    
   
    
    #if true
    
    var minimizer = TopologyMinimizer(topology)
    print(minimizer.createForces()[0])
    print(minimizer.createForces()[1])
    print(minimizer.createForces()[2])
    print(minimizer.createForces()[3])
    print(minimizer.createForces()[4])
    print(minimizer.createKineticEnergy())
    print(minimizer.createPotentialEnergy())
    
    topology = minimizer.topology
    
    /*
     // stretch
     SIMD3<Float>(0.0, -725.7271, -2052.6667)
     SIMD3<Float>(-1777.6615, -725.7271, 1026.3333)
     SIMD3<Float>(2405.9875, 1964.4801, 1389.0975)
     SIMD3<Float>(2405.9875, -1964.4807, 1389.0975)
     SIMD3<Float>(0.0, -2211.546, 0.0)
     0.0
     12433.641400284208
     
     // stretch, bend, stretch-bend
     SIMD3<Float>(-132.01414, -797.58563, -2027.2562)
     SIMD3<Float>(-1821.6626, -797.58563, 899.3005)
     SIMD3<Float>(2599.7678, 2182.5303, 1500.9762)
     SIMD3<Float>(2599.7688, -2182.5283, 1500.9768)
     SIMD3<Float>(0.00055743195, -2208.555, -0.00032305715)
     0.0
     13121.003463542003
     
     // nonbonded, no cutoff
     SIMD3<Float>(-110.91366, -124.245384, -54.57905)
     SIMD3<Float>(-114.343895, -176.19177, -631.09705)
     SIMD3<Float>(-128.84975, -86.52675, -247.82759)
     SIMD3<Float>(-128.84976, 86.52674, -247.82762)
     SIMD3<Float>(-30.36326, -128.19667, -58.84188)
     0.0
     70085.65484127567
     
     // nonbonded, cutoff
     SIMD3<Float>(-110.91168, -124.24184, -54.591198)
     SIMD3<Float>(-114.33922, -176.18939, -631.0915)
     SIMD3<Float>(-128.81842, -86.51363, -247.79065)
     SIMD3<Float>(-128.81844, 86.51362, -247.79068)
     SIMD3<Float>(-30.381937, -128.20197, -58.850136)
     0.0
     70858.13469640861
     */
    
    #else
    
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    paramsDesc.forces = [.nonbonded]
    paramsDesc.hydrogenMassScale = 1
    var parameters = try! MM4Parameters(descriptor: paramsDesc)
//    for i in parameters.atoms.indices {
//      parameters.atoms.parameters[i].hydrogenReductionFactor = 1
//    }
    
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = parameters
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    forceField.positions = topology.atoms.map(\.position)
    
    var stateDesc = MM4StateDescriptor()
    stateDesc.positions = true
    stateDesc.forces = true
    stateDesc.energy = true
    let state = forceField.state(descriptor: stateDesc)
    
    /*
     // stretch
     SIMD3<Float>(0.0, -725.7272, -2052.6667)
     SIMD3<Float>(-1777.6616, -725.7272, 1026.3334)
     SIMD3<Float>(2405.9875, 1964.4803, 1389.0975)
     SIMD3<Float>(2405.9875, -1964.481, 1389.0975)
     SIMD3<Float>(0.0, -2211.546, 0.0)
     0.0
     12433.64208984375
     
     // stretch, bend
     SIMD3<Float>(-130.03574, -796.51025, -2027.6411)
     SIMD3<Float>(-1821.0067, -796.51025, 901.20636)
     SIMD3<Float>(2604.668, 2188.6755, 1503.8052)
     SIMD3<Float>(2604.669, -2188.6736, 1503.8058)
     SIMD3<Float>(0.0005569458, -2211.546, -0.00031852722)
     0.0
     13176.492263793945
     
     // stretch, bend, stretch-bend
     SIMD3<Float>(-132.01413, -797.5857, -2027.2563)
     SIMD3<Float>(-1821.6627, -797.5857, 899.3006)
     SIMD3<Float>(2599.7678, 2182.5305, 1500.9761)
     SIMD3<Float>(2599.7688, -2182.5283, 1500.9767)
     SIMD3<Float>(0.0005569458, -2208.555, -0.00031661987)
     0.0
     13121.003219604492
     
     // nonbonded
     SIMD3<Float>(130.98947, -438.1439, -1355.8594)
     SIMD3<Float>(-1117.9431, -490.38287, 235.38556)
     SIMD3<Float>(-1093.7207, -853.2757, -799.5361)
     SIMD3<Float>(-1093.7207, 853.27545, -799.5366)
     SIMD3<Float>(-26.69083, -982.52155, -52.7677)
     0.0
     313764.90234375
     
     // nonbonded w/ HRed
     
     */
    
    print(state.forces![0])
    print(state.forces![1])
    print(state.forces![2])
    print(state.forces![3])
    print(state.forces![4])
    print(state.kineticEnergy!)
    print(state.potentialEnergy!)
    
//    forceField.minimize(tolerance: 9)
//    for i in topology.atoms.indices {
//      topology.atoms[i].position = forceField.positions[i]
//    }
    
    #endif
  }
}

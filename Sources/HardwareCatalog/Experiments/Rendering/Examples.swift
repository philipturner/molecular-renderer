//
//  Examples.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/24/23.
//

import Foundation
import MolecularRenderer
import Numerics

class CasingAtomProvider: MRAtomProvider {
  private let atomsDict: [String: [MRAtom]]
  
  init() {
    let urls = [
      "casings/Embedded Bushing in SiC with Shaft",
      "casings/Pump Casing",
      "casings/SiC Large Slab",
      "casings/SiC Small Slab",
    ]
    
    var selfAtomsDict: [String: [MRAtom]] = [:]
    for url in urls {
      let parser = NanoEngineerParser(partLibPath: url)
      selfAtomsDict[url] = parser._atoms
    }
    self.atomsDict = selfAtomsDict
  }
  
  func atoms(time: MRTime) -> [MRAtom] {
    let t = Float(time.absolute.seconds)
    
    var currentAtomsDict: [String: [MRAtom]] = [:]
    for key in atomsDict.keys {
      var translation: SIMD3<Float>
      
      switch key {
      case "casings/Embedded Bushing in SiC with Shaft":
        translation = [-3, 0, -3]
        break
      case "casings/Pump Casing":
        translation = [-1, 0, -1]
        break
      case "casings/SiC Large Slab":
        translation = [+1, 0, +1]
        break
      case "casings/SiC Small Slab":
        translation = [+3, 0, +3]
        break
      default:
        fatalError()
      }
      
      // Rotate once every two seconds.
      let rotation = Quaternion<Float>(angle: t * .pi, axis: [0, 0, 1])
      var atoms = atomsDict[key]!
      for i in 0..<atoms.count {
        var atom = atoms[i]
        var pos = SIMD3<Float>(atom.origin)
        pos = rotation.act(on: pos)
        pos += translation
        atom.origin = pos
        atoms[i] = atom
      }
      currentAtomsDict[key] = atoms
    }
    return currentAtomsDict.values.flatMap { $0 }
  }
}

struct ExampleProviders {
  static func planetaryGearBox() -> NanoEngineerParser {
    NanoEngineerParser(
      partLibPath: "gears/MarkIII[k] Planetary Gear Box")
  }
  
  static func adamantaneHabTool() -> PDBParser {
    let adamantaneHabToolURL: URL = {
      return URL(string: "https://gist.githubusercontent.com/philipturner/6405518fadaf902492b1498b5d50e170/raw/d660f82a0d6bc5c84c0ec1cdd3ff9140cd7fa9f2/adamantane-thiol-Hab-tool.pdb")!
    }()
    return PDBParser(url: adamantaneHabToolURL, hasA1: true)
  }
  
  static func fineMotionController() -> NanoEngineerParser {
    NanoEngineerParser(
      partLibPath: "others/Fine Motion Controller")
  }
  
  // https://raw.githubusercontent.com/eudoxia0/MNT/master/gears/nanotube-worm-drive.mmp
  // https://raw.githubusercontent.com/eudoxia0/MNT/master/transport/fullerene-conveyor-cart.mmp
  // https://raw.githubusercontent.com/eudoxia0/MNT/master/transport/gantry.mmp
  
  //    self.atomProvider = PlanetaryGearBox()
  //    self.atomProvider = APMBootstrapper()
  //    self.atomProvider = ExampleProviders.fineMotionController()
  //    self.atomProvider = MassiveDiamond(outerSize: 100, thickness: 2)
}

struct ExampleMolecules {
  // Structure sourced from:
  // https://commons.wikimedia.org/wiki/File:Ethylene-CRC-MW-dimensions-2D-Vector.svg
  struct Ethylene: MRAtomProvider {
    var _atoms: [MRAtom]
    
    init() {
      let z_offset: Float = -1 // -2
      let c_offset_x: Float = 0.1339 / 2 // 0.20
      let carbon_origins: [SIMD3<Float>] = [
        SIMD3(-c_offset_x, 0, z_offset),
        SIMD3(+c_offset_x, 0, z_offset),
      ]
      
      let angle: Float = (180 - 121.3) * .pi / 180
      let h_offset_x: Float = 0.1087 * cos(angle) + c_offset_x // 0.50
      let h_offset_y: Float = 0.1087 * sin(angle) // 0.25
      let hydrogen_origins: [SIMD3<Float>] = [
        SIMD3(-h_offset_x, -h_offset_y, z_offset),
        SIMD3(-h_offset_x, +h_offset_y, z_offset),
        SIMD3(+h_offset_x, -h_offset_y, z_offset),
        SIMD3(+h_offset_x, +h_offset_y, z_offset),
      ]
      
      self._atoms = hydrogen_origins.map {
        MRAtom(origin: $0, element: 1)
      }
      self._atoms += carbon_origins.map {
        MRAtom(origin: $0, element: 6)
      }
    }
    
    func atoms(time: MRTime) -> [MRAtom] {
      return _atoms
    }
  }
  
  struct TaggedEthylene: MRAtomProvider {
    var _atoms: [MRAtom]
    
    init() {
      let ethylene = Ethylene()
      self._atoms = ethylene._atoms
      
      let firstHydrogen = _atoms.firstIndex(where: { $0.element == 1 })!
      let firstCarbon = _atoms.firstIndex(where: { $0.element == 6 })!
      _atoms[firstHydrogen].element = 0
      _atoms[firstCarbon].element = 220
    }
    
    func atoms(time: MRTime) -> [MRAtom] {
      return _atoms
    }
  }
  
  struct GoldSurface: MRAtomProvider {
    var _atoms: [MRAtom]
    
    init() {
      var origins: [SIMD3<Float>] = []
      
      let size = 2
      let separation: Float = 0.50
      for x in -size...size {
        for y in -size...size {
          for z in -size...size {
            let coords = SIMD3<Int>(x, y, z)
            origins.append(separation * SIMD3<Float>(coords))
          }
        }
      }
      
      _atoms = origins.map {
        MRAtom(origin: $0, element: 79)
      }
      
      // Sulfur atoms are interspersed. Although this is not a realistic
      // substance, it ensures the renderer provides enough contrast between the
      // colors for S and Au.
      _atoms += origins.map {
        let origin = $0 + SIMD3(repeating: separation / 2)
        return MRAtom(origin: origin, element: 16)
      }
      
      let pdbAtoms = ExampleProviders.adamantaneHabTool()._atoms
      _atoms += pdbAtoms.map {
        let origin = $0.origin + [0, 2, 0]
        return MRAtom(origin: origin, element: $0.element)
      }
    }
    
    func atoms(time: MRTime) -> [MRAtom] {
      return _atoms
    }
  }
  
  struct Cyclosilane: MRAtomProvider {
    var _atoms: [MRAtom]
    
    // Accepts either C-C-C-C-Si or C-C-Si-C-Si.
    init(name: String) {
      _atoms = []
      switch name {
      case "C-C-C-C-Si":
//        Si-C-C-C 38.266026°
//        C-C-C-C 52.33149°
//        C-C-C-Si 38.265625°
//        C-C-Si-C 13.626033°
//        C-Si-C-C 13.626572°
        _atoms += [
          MRAtom(origin: [0.374173574134,    -0.038215551663,     0.029145704021], element:  6),
          MRAtom(origin: [0.042208845189,     0.048173538152,     1.534234181840], element: 6),
          MRAtom(origin: [1.361498934513,    -0.018980953310 ,    2.315643962314], element: 6),
          MRAtom(origin: [2.312087681507 ,    1.052449628780 ,    1.739994005084], element: 6),
          MRAtom(origin:  [1.963073497412 ,    0.983260933736 ,   -0.121194257135], element:   14),
          MRAtom(origin:  [-0.450970884385,     0.305930079906 ,   -0.599725255994], element:   1),
          MRAtom(origin: [ 0.578396582086 ,   -1.080456385801 ,   -0.241414542186], element:   1),
          MRAtom(origin: [ -0.650101611915 ,   -0.740842053665 ,    1.846013871606], element:   1),
          MRAtom(origin: [ -0.442582735493 ,    1.009311463738 ,    1.748675237095], element:   1),
          MRAtom(origin: [ 1.801521737141 ,   -1.014502527347  ,   2.173832182598], element:   1),
          MRAtom(origin: [ 1.199157166904 ,    0.113634248537 ,    3.390401627570], element:   1),
          MRAtom(origin: [ 3.354868454340 ,    0.875450216430 ,    2.015780146801], element:   1),
          MRAtom(origin: [ 2.033349111174 ,    2.037454902073 ,    2.131459294476], element:   1),
          MRAtom(origin: [ 3.023113895097  ,   0.298365207660,    -0.894804602536], element:   1),
          MRAtom(origin:  [1.750548752298  ,   2.319091252776,    -0.722552555554], element:   1),
        ]
        
      case "C-C-Si-C-Si":
//        Si-C-C-Si 45.47622°
//        C-C-Si-C 37.430264°
//        C-Si-C-Si 13.232536°
//        Si-C-Si-C 9.339233°
//        C-Si-C-C 34.919006°
        _atoms += [
          MRAtom(origin: [0.436559989542,    -0.021509834557 ,   -0.070008725009], element:    6),
          MRAtom(origin: [ -0.175030171743 ,    0.040664578954  ,   1.352031202458], element:     6),
          MRAtom(origin: [1.270072281487 ,   -0.070457393573 ,    2.567966751376], element:      14),
          MRAtom(origin: [2.592470798994 ,    0.941963695435 ,    1.674120078942], element:      6),
          MRAtom(origin: [1.923771464832 ,    1.149968957044 ,   -0.082753592247], element:      14),
          MRAtom(origin: [-0.301082787522 ,    0.215712235450 ,   -0.843118691980], element:      1),
          MRAtom(origin: [ 0.790877052560 ,   -1.040136410532 ,   -0.273958643718], element:      1),
          MRAtom(origin: [ -0.928542417136  ,  -0.737929543456 ,    1.507145436186], element:      1),
          MRAtom(origin: [ -0.681533994528 ,    1.003948511432 ,    1.494778642656], element:      1),
          MRAtom(origin: [  1.705503094093 ,   -1.480021075740  ,   2.699020954727], element:      1),
          MRAtom(origin: [  0.939801326509 ,    0.446486514825  ,   3.914300446718], element:      1),
          MRAtom(origin: [ 3.559494280506  ,   0.431547810184 ,    1.681437207276], element:      1),
          MRAtom(origin: [ 2.737610891177 ,    1.914388357462  ,   2.153497345019], element:      1),
          MRAtom(origin: [ 2.912045637587  ,   0.812839717055 ,   -1.130868413736], element:      1),
          MRAtom(origin: [ 1.468325553642  ,   2.542657880016 ,   -0.298100998669], element:      1),
        ]
      default:
        fatalError("Unrecognized sequence: \(name)")
      }
      
      for i in _atoms.indices {
        _atoms[i].origin /= 10
      }
      
      for i in 0..<5 {
        let indexA = (i + 4) % 5
        let indexB = i % 5
        let indexC = (i + 1) % 5
        let indexD = (i + 2) % 5
        
        func repr(index: Int) -> (String) {
          if _atoms[index].element == 14 {
            return "Si"
          } else if _atoms[index].element == 6 {
            return "C"
          } else if _atoms[index].element == 1 {
            return "H"
          } else {
            fatalError("This should never happen.")
          }
        }
        
        var output: String = ""
        output += repr(index: indexA) + "-"
        output += repr(index: indexB) + "-"
        output += repr(index: indexC) + "-"
        output += repr(index: indexD)
        
        let pos1 = _atoms[indexA].origin
        let pos2 = _atoms[indexB].origin
        let pos3 = _atoms[indexC].origin
        let pos4 = _atoms[indexD].origin
        
        var delta12 = pos1 - pos2
        var delta43 = pos4 - pos3
        let perpComponent = cross_platform_normalize(pos2 - pos3)
        delta12 -= cross_platform_dot(delta12, perpComponent) * perpComponent
        delta43 -= cross_platform_dot(delta43, perpComponent) * perpComponent
        delta12 = cross_platform_normalize(delta12)
        delta43 = cross_platform_normalize(delta43)
        
        let quaternion = Quaternion<Float>(from: delta12, to: delta43)
        let angle = quaternion.angle * 180 / .pi
        output += " \(angle)°"
        print(output)
      }
    }
    
    func atoms(time: MRTime) -> [MRAtom] {
      return _atoms
    }
  }
}

extension ExampleProviders {
  static func strainedShellStructure() -> any MRAtomProvider {
    //    let url2 = URL(filePath: "/Users/philipturner/Desktop/armchair-graphane-W-structure.pdb")
    
//    let url2 = URL(filePath: "/Users/philipturner/Documents/OpenMM/Renders/Imports/sleeve-to-gear.mmp")
//    let parsed = PDBParser(url: url2, hasA1: true)
//        let parsed = NanoEngineerParser(path: url2.absoluteString)
    
        let parsed = NanoEngineerParser(
          partLibPath: "bearings/Hydrocarbon Strained Sleeve Bearing.mmp")
    let centers = parsed._atoms.compactMap { atom -> SIMD3<Float>? in
      if atom.element == 6 {
        return atom.origin
      } else {
        return nil
      }
    }
    //
    var diamondoid = Diamondoid(carbonCenters: centers)
    diamondoid.translate(offset: -diamondoid.createCenterOfMass())
    diamondoid.rotate(angle: Quaternion<Float>(angle: .pi / 2, axis: [1, 0, 0]))
    
    let simulation = _Old_MM4(diamondoid: diamondoid, fsPerFrame: 20)
    let ranges = simulation.rigidBodies
    let state = simulation.context.state(types: [.positions, .velocities])
    let statePositions = state.positions
    let stateElements = simulation.provider.elements
    var rigidBodies = ranges.map { range -> Diamondoid in
      var centers: [SIMD3<Float>] = []
      for index in range {
        guard stateElements[index] == 6 else {
          continue
        }
        
        let position = statePositions[index]
        centers.append(SIMD3(position))
      }
      return Diamondoid(carbonCenters: centers)
    }
    print(rigidBodies.count)
    print(rigidBodies[0].atoms.count)
    print(rigidBodies[1].atoms.count)
    
    // Radius: 0.957 nm
    // Angular velocity: 0.01 rad/ps
    // Velocity: radius * angular velocity * 1000 m/s = 10 m/s
    rigidBodies[1].angularVelocity = Quaternion<Float>(
      angle: 0.01, axis: [0, 0, 1])
//    rigidBodies[1].angularVelocity = Quaternion<Float>(
//      angle: 0.00, axis: [0, 0, 1])
    
    return MovingAtomProvider(
      rigidBodies[0].atoms + rigidBodies[1].atoms,
      velocity: SIMD3(1, 0, 0))
    
    // Also run for 10 nanoseconds
//    simulation = _Old_MM4(diamondoids: rigidBodies, fsPerFrame: 2000) // 0.5 -> 2 ps
//    simulation.simulate(ps: 5000) // 1 ns -> 5 ns
    
    //    self.atomProvider = ArrayAtomProvider(diamondoid.atoms)
    //
    //    ////    }
    //        let provider = ArrayAtomProvider(centers.map {
    //          MRAtom(origin: $0, element: 6)
    //        })
//    return simulation.provider
    
  }
}

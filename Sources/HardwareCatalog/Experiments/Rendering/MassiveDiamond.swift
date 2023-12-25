//
//  MassiveDiamond.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/12/23.
//

import Foundation
import MolecularRenderer
import OpenMM

#if false

// Adversarial test case to find where dense grids break down, and sparse grids
// are needed.
// - Benchmarked quality: 7 samples/pixel
// - Benchmarked position: [0, 1.5, 0], looking at -Y with camera space up = +X
// - outerSize = 10, thickness 1: 44705 atoms
// - outerSize = 100, thickness 2: 947968 atoms
//
// Geometry stage:
//
// outerSize = 10
// - 16-bit sparse: TODO
// - 32-bit sparse: TODO
// - 16-bit dense: 612 µs
// - 32-bit dense: 562 µs
// outerSize = 100
// - 16-bit sparse: TODO
// - 32-bit sparse: TODO
// - 32-bit dense: 3128 µs
//
// Render stage:
//
// outerSize = 10
// - 16-bit sparse: TODO
// - 32-bit sparse: TODO
// - 16-bit dense: 9.05 ms (failing right now)
// - 32-bit dense: 8.31 ms
//
// outerSize = 100
// - 16-bit sparse: TODO
// - 32-bit sparse: TODO
// - 32-bit dense: 4.11 ms
struct MassiveDiamond: MRAtomProvider {
  var _atoms: [MRAtom]
  
  init(outerSize: Int, thickness: Int? = nil) {
//    let extraDepth: Int = 100
//    let dimensions: SIMD3<Int> = [outerSize, outerSize + extraDepth, outerSize]
    let dimensions: SIMD3<Int> = [outerSize, outerSize, outerSize]
    
    let axesOpenLower: SIMD3<Int> = [0, 0, 0]
    let axesOpenUpper: SIMD3<Int> = [0, 1, 0]
//    let axesOpenUpper: SIMD3<Int> = [0, 0, 0]
//    let plane = CrystalPlane.fcc100(outerSize, extraDepth, outerSize)
    let plane = CrystalPlane.fcc100(outerSize, outerSize, outerSize)
    
    var hollowStart: SIMD3<Int>?
    var hollowEnd: SIMD3<Int>?
    if let thickness {
      hollowStart = SIMD3<Int>(repeating: .zero) &+ thickness
      hollowEnd = dimensions &- thickness
      
      for i in 0..<3 {
        if axesOpenLower[i] > 0 {
          hollowStart![i] = -1
        }
        if axesOpenUpper[i] > 0 {
          hollowEnd![i] = dimensions[i] + 1
        }
      }
    }
    
//    let latticeConstant: Float = 0.357
    let cuboid = DiamondCuboid(
      latticeConstant: 0.357,
      hydrogenBondLength: 0.109,
      plane: plane,
      hollowStart: hollowStart,
      hollowEnd: hollowEnd)
    _atoms = cuboid.atoms
    
//    for i in 0..<_atoms.count {
//      _atoms[i].origin.y -= Float(extraDepth) / 2 * latticeConstant
//    }
    
    print("Number of atoms: \(_atoms.count)")
    
  }
  
  func atoms(time: MRTime) -> [MRAtom] {
    return self._atoms
  }
  
  // Find the atom closest to the center, then generate a CSV for a cumulative
  // C-C vdW energy function and cumulative compute cost w.r.t. distance. At
  // each discrete interval in radius, remove atoms from the front of the list.
  func nonbondedEnergyData() -> String {
    var minimum: SIMD3<Float> = .init(repeating: 1000)
    var maximum: SIMD3<Float> = .init(repeating: -1000)
    var carbonAtoms = _atoms.filter { $0.element == 6 }
    
    for atom in carbonAtoms {
      minimum.replace(with: atom.origin, where: atom.origin .< minimum)
      maximum.replace(with: atom.origin, where: atom.origin .> maximum)
    }
    let center = (minimum + maximum) / 2
    
    let minimumIndex = carbonAtoms.indices.min(by: {
      let firstOrigin = carbonAtoms[$0].origin
      let secondOrigin = carbonAtoms[$1].origin
      return cross_platform_distance(firstOrigin, center) < cross_platform_distance(secondOrigin, center)
    })!
    let centerAtom = carbonAtoms.remove(at: minimumIndex)
    
    carbonAtoms.sort(by: {
			let dist1 = cross_platform_distance($0.origin, centerAtom.origin)
			let dist2 = cross_platform_distance($1.origin, centerAtom.origin)
      return dist1 < dist2
    })
		var distances = carbonAtoms.map {
			cross_platform_distance($0.origin, centerAtom.origin)
		}
		distances.reverse()
		
		let bucketSizeInNm: Float = 0.01
		var totalAtoms: Int = 0
		var totalEnergyInZJ: Float = 0
		var totalForceInPN: Float = 0
		var currentDistanceInNm: Float = 0
		
		// Assuming the diamond's outer size is 30 cells, the max radius is 5 nm.
		var output: String = ""
		output += "distance (nm), energy (zJ), force (pN), accuracy, atoms\n"
//		output += "\(minimum)\n"
//		output += "\(maximum)\n"
		while currentDistanceInNm < 5 {
			currentDistanceInNm += bucketSizeInNm
			while (distances.last ?? 10) < currentDistanceInNm {
				let r = distances.removeLast()
				totalAtoms += 1
				
				let length = Float(1.960 * OpenMM_NmPerAngstrom)
				let epsilon = Float(0.037 * OpenMM_KJPerKcal)
				
				let ratio = (length / r)
				let ratioSquared = ratio * ratio
				let energyInKJPerMol = epsilon * (
					-2.25 * ratioSquared * ratioSquared * ratioSquared +
				 1.84e5 * exp(-12.00 * (r / length))
				)
				totalEnergyInZJ += 1.660578 * -energyInKJPerMol
				
				let force = epsilon * (
					-2.25 * -6 * ratioSquared * ratioSquared * ratioSquared / r +
					1.84e5 * (-12.00 / length) * exp(-12.00 * (r / length))
				)
				totalForceInPN += 1.660578 * abs(force)
			}
			output += "\(String(format: "%.2f", currentDistanceInNm)), "
			var energyToShow: Float
			if totalEnergyInZJ == 0 {
				energyToShow = -3.79734 + 1.27698
			} else {
				energyToShow = totalEnergyInZJ + 1.27698
			}
			output += "\(String(format: "%.3f", energyToShow)), "
			output += "\(String(format: "%.3f", totalForceInPN)), "
			
			let accuracy = 1 - energyToShow / (-3.79734 + 1.27698)
			output += "\(String(format: "%.3f", accuracy)), "
			output += "\(totalAtoms)\n"
		}
		
    return output
  }
}

// MARK: - Old Crystolecule Geometry Backend

enum CrystalPlane {
  case fcc100(Int, Int, Int)
  case fcc111(Int, Int, Int)
}

struct GoldCuboid {
  var latticeConstant: Float
  let element: Int = 79
  var plane: CrystalPlane
  
  var atoms: [MRAtom] = []
  
  init(
    latticeConstant: Float,
    plane: CrystalPlane
  ) {
    self.latticeConstant = latticeConstant
    self.plane = plane
    
    switch plane {
    case .fcc100(let width, let height, let depth):
      precondition(
        width >= 2 && height >= 2 && depth >= 2, "Volume too small.")
      var numAtoms = width * height * depth
      numAtoms += (width - 1) * (height - 1) * depth
      numAtoms += (width - 1) * height * (depth - 1)
      numAtoms += width * (height - 1) * (depth - 1)
      
      let offset: SIMD3<Float> = [
        -Float((width - 1) / 2),
        -Float((height - 1) / 2),
        -Float((depth - 1) / 2),
      ]
      for i in 0..<width {
        for j in 0..<height {
          for k in 0..<depth {
            let coords = SIMD3<Int>(i, j, k)
            var origin = SIMD3<Float>(coords) + offset
            origin *= latticeConstant
            atoms.append(MRAtom(origin: origin, element: element))
          }
        }
      }
      for i in 0..<width - 1 {
        for j in 0..<height - 1 {
          for k in 0..<depth {
            let coords = SIMD3<Int>(i, j, k)
            var origin = SIMD3<Float>(coords) + offset
            origin.x += 0.5
            origin.y += 0.5
            origin *= latticeConstant
            atoms.append(MRAtom(origin: origin, element: element))
          }
        }
      }
      for i in 0..<width - 1 {
        for j in 0..<height {
          for k in 0..<depth - 1 {
            let coords = SIMD3<Int>(i, j, k)
            var origin = SIMD3<Float>(coords) + offset
            origin.x += 0.5
            origin.z += 0.5
            origin *= latticeConstant
            atoms.append(MRAtom(origin: origin, element: element))
          }
        }
      }
      for i in 0..<width {
        for j in 0..<height - 1 {
          for k in 0..<depth - 1 {
            let coords = SIMD3<Int>(i, j, k)
            var origin = SIMD3<Float>(coords) + offset
            origin.y += 0.5
            origin.z += 0.5
            origin *= latticeConstant
            atoms.append(MRAtom(origin: origin, element: element))
          }
        }
      }
    case .fcc111(let width, let diagonalHeight, let layers):
      // Based on: https://chem.libretexts.org/Bookshelves/Physical_and_Theoretical_Chemistry_Textbook_Maps/Surface_Science_(Nix)/01%3A_Structure_of_Solid_Surfaces/1.03%3A_Surface_Structures-_fcc_Metals#:~:text=in%20the%20troughs)-,The%20fcc%20(111)%20Surface,%2Dfold%2C%20hexagonal)%20symmetry.
      let spacingX = latticeConstant
      let spacingY = latticeConstant * sqrt(3)
      let spacingZ = latticeConstant * 2 * sqrt(2.0 / 3)
      _ = spacingX
      _ = spacingY
      _ = spacingZ
      _ = width
      _ = diagonalHeight
      _ = layers
      fatalError("(111) not supported yet.")
    }
  }
}

struct DiamondCuboid {
  var latticeConstant: Float
  var hydrogenBondLength: Float
  let element: Int = 6
  var plane: CrystalPlane
  
  // Inclusive start/end of the hollow part.
  var hollowStart: SIMD3<Int>?
  var hollowEnd: SIMD3<Int>?
  
  var atoms: [MRAtom] = []
  
  init(
    latticeConstant: Float,
    hydrogenBondLength: Float,
    plane: CrystalPlane,
    hollowStart: SIMD3<Int>? = nil,
    hollowEnd: SIMD3<Int>? = nil
  ) {
    self.latticeConstant = latticeConstant
    self.hydrogenBondLength = hydrogenBondLength
    self.plane = plane
    self.hollowStart = hollowStart
    self.hollowEnd = hollowEnd
    
    var width: Int
    var height: Int
    var depth: Int
    switch plane {
    case .fcc100(let _width, let _height, let _depth):
      width = _width
      height = _height
      depth = _depth
    default:
      fatalError("Need (100) plane.")
    }
    
    struct Hydrogen {
      var origin: SIMD3<Float>
      var direction: SIMD3<Float>
    }
    var carbons: [SIMD3<Float>] = []
    var hydrogens: [Hydrogen] = []
    
    struct Lattice {
      var bounds: SIMD3<Int>
      var offset: SIMD3<Float>
      var alternating: Bool = false
      var hasHydrogens: Bool = true
    }
    let lattices: [Lattice] = [
      Lattice(
        bounds: [width + 1, height + 1, depth + 1], offset: [0, 0, 0],
        alternating: true),
      
      Lattice(bounds: [width + 1, height, depth], offset: [0, 0.5, 0.5]),
      Lattice(bounds: [width, height + 1, depth], offset: [0.5, 0, 0.5]),
      Lattice(bounds: [width, height, depth + 1], offset: [0.5, 0.5, 0]),
      
      Lattice(
        bounds: [width, height, depth], offset: [0.25, 0.25, 0.25],
        hasHydrogens: false),
      Lattice(
        bounds: [width, height, depth], offset: [0.25, 0.75, 0.75],
        hasHydrogens: false),
      Lattice(
        bounds: [width, height, depth], offset: [0.75, 0.25, 0.75],
        hasHydrogens: false),
      Lattice(
        bounds: [width, height, depth], offset: [0.75, 0.75, 0.25],
        hasHydrogens: false),
    ]
    
    let center: SIMD3<Float> = [
      Float(width) / 2,
      Float(height) / 2,
      Float(depth) / 2,
    ]
    var minCoords: SIMD3<Float> = center
    var maxCoords: SIMD3<Float> = center
    if let hollowStart, let hollowEnd {
      minCoords = SIMD3(hollowStart)
      maxCoords = SIMD3(hollowEnd)
    }
    
    for lattice in lattices {
      for i in 0..<lattice.bounds.x {
        for j in 0..<lattice.bounds.y {
          for k in 0..<lattice.bounds.z {
            if lattice.alternating {
              if (i ^ j ^ k) & 1 != 0 {
                continue
              }
            }
            
            var coords = SIMD3<Float>(SIMD3(i, j, k))
            coords += lattice.offset
            if all(coords .> minCoords) && all(coords .< maxCoords) {
              continue
            }
            carbons.append(coords)
            
            // Add hydrogens to the outside.
            guard lattice.hasHydrogens else {
              continue
            }
            let bounds = SIMD3<Float>(SIMD3(width, height, depth))
            if any(coords .== 0) || any(coords .== bounds) {
              var direction: SIMD3<Float> = .zero
              for component in 0..<3 {
                if coords[component] == 0 {
                  direction[component] = -1
                } else if coords[component] == bounds[component] {
                  direction[component] = +1
                }
              }
              hydrogens.append(
                Hydrogen(origin: coords, direction: direction))
            }
            
            var addInnerHydrogen = false
            if any(coords .== minCoords) || any(coords .== maxCoords) {
              if all((coords .>= minCoords) .| (coords .>= maxCoords)) {
                addInnerHydrogen = true
              }
            }
            if addInnerHydrogen {
              var direction: SIMD3<Float> = .zero
              for component in 0..<3 {
                if coords[component] == minCoords[component] {
                  direction[component] = +1
                } else if coords[component] == maxCoords[component] {
                  direction[component] = -1
                }
              }
              hydrogens.append(
                Hydrogen(origin: coords, direction: direction))
            }
          }
        }
      }
    }
    
    // Offset by the center, then scale by the lattice constant.
    for coords in carbons {
      let origin = latticeConstant * (coords - center)
      atoms.append(MRAtom(origin: origin, element: 6))
    }
    
    // Use an additional physical constant for hydrogens.
    for hydrogen in hydrogens {
      var origin = latticeConstant * (hydrogen.origin - center)
      origin += hydrogenBondLength * cross_platform_normalize(hydrogen.direction)
      atoms.append(MRAtom(origin: origin, element: 1))
    }
  }
}

class _Old_APMBootstrapper: MRAtomProvider {
  var surface = GoldSurface()
  var habTools: [HabTool]
  var reportedAtoms = false
  
  init() {
    let numTools = 100
    srand48(79) // seed with atomic number of Au
    var offsets: [SIMD2<Float>] = []
    
    for i in 0..<numTools {
      var offset = SIMD2(Float(drand48()), Float(drand48()))
      offset.x = cross_platform_mix(-7, 7, offset.x)
      offset.y = cross_platform_mix(-7, 7, offset.y)
      
      var numTries = 0
      while offsets.contains(where: { cross_platform_distance($0, offset) < 1.0 }) {
        numTries += 1
        if numTries > 100 {
          print(offsets)
          print(offset)
          fatalError("Random generation failed to converge @ \(i).")
        }
        
        offset = SIMD2(Float(drand48()), Float(drand48()))
        offset.x = cross_platform_mix(-7, 7, offset.x)
        offset.y = cross_platform_mix(-7, 7, offset.y)
      }
      offsets.append(offset)
    }
    
    // Measured in revolutions, not radians.
    let rotations: [Float] = (0..<numTools).map { _ in
      return Float(drand48())
    }
    
    habTools = zip(offsets, rotations).map { (offset, rotation) in
      let x: Float = offset.x
      let z: Float = offset.y
      let radians = rotation * 2 * .pi
      let orientation = Quaternion<Float>(angle: radians, axis: [0, 1, 0])
      return HabTool(x: x, z: z, orientation: orientation)
    }
  }
  
  func atoms(time: MRTime) -> [MRAtom] {
    var atoms = surface.atoms
    for habTool in habTools {
      atoms.append(contentsOf: habTool.atoms)
    }
    if !reportedAtoms {
      reportedAtoms = true
      print("Rendering \(atoms.count) atoms.")
    }
    return atoms
  }
  
  struct HabTool {
    static let baseAtoms = { () -> [MRAtom] in
      let url = URL(string: "https://gist.githubusercontent.com/philipturner/6405518fadaf902492b1498b5d50e170/raw/d660f82a0d6bc5c84c0ec1cdd3ff9140cd7fa9f2/adamantane-thiol-Hab-tool.pdb")!
      let parser = PDBParser(url: url, hasA1: true)
      var atoms = parser._atoms
      
      var sulfurs = atoms.filter { $0.element == 16 }
      precondition(sulfurs.count == 3)
      
      let normal = cross_platform_cross(sulfurs[2].origin - sulfurs[0].origin,
                                        sulfurs[1].origin - sulfurs[0].origin)
      
      let rotation = Quaternion<Float>(from: cross_platform_normalize(normal), to: [0, 1, 0])
      for i in 0..<atoms.count {
        var atom = atoms[i]
        atom.origin = rotation.act(on: atom.origin)
        atom.origin += [0, 1, 0]
        atoms[i] = atom
      }
      
      sulfurs = atoms.filter { $0.element == 16 }
      let height = sulfurs[0].origin.y
      for i in 0..<atoms.count {
        atoms[i].origin.y -= height
      }
      
      return atoms
    }()
    
    var atoms: [MRAtom]
    
    init(x: Float, z: Float, orientation: Quaternion<Float>) {
      self.atoms = Self.baseAtoms.map { input in
        var atom = input
        atom.origin = orientation.act(on: atom.origin)
        atom.origin.y += 0.4
        atom.origin.x += x
        atom.origin.z += z
        return atom
      }
    }
  }

  struct GoldSurface {
    var atoms: [MRAtom]
    
    init() {
      let spacing: Float = 0.40782
      let size = Int(16 / spacing)
      let cuboid = GoldCuboid(
        latticeConstant: spacing, plane: .fcc100(size, 3, size))
      self.atoms = cuboid.atoms
      
      for i in 0..<atoms.count {
        atoms[i].origin.y -= 1 * spacing
      }
    }
  }
}

#endif

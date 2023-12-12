//
//  Bootstrapping_Tripod.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/10/23.
//

import HDL
import MolecularRenderer
import Numerics

// Create a bunch of tripod objects with randomly chosen feedstocks and randomly
// chosen locations, distributed in a circle around the surface's center. Use
// rejection sampling to exclude the build plate and already chosen locations.
// Not all locations will be filled.
//
// 1) Debug the position and alignment of a single tripod, as well as lattice
//    vectors. Estimate how many tripods could fit on the surface. ✅
// 2) Get to where you're randomly initializing tripods in a circle, but not
//    yet clearing room for a build plate. ✅
// 3) Add silicon radical moieties to the tips of the tripods. Store it in a
//    property separate from the bulk atoms, so it can be detached later.
// 4) Create some code that searches for the closest tripod with a particular
//    moiety attached, then shifts that tripod's moiety upward to visualize.
// 5) Create some code that moves the surface and detaches a moiety from a
//    tripod.
// 6) Don't worry about putting the AFM on a trajectory where it needs to avoid
//    the tripods. The code for searching for unused tips is already complex
//    enough and sufficient for an animation.
//
// Finish the rest of this scene another time; each component of the project
// can be worked on in bits.

extension Bootstrapping {
  struct Tripod {
    // Concentration in solution should be something like:
    // - 5% failures
    // - 15% silylene
    // - 75% silicon
    // - 5% germanene
    // The numbers will be randomly selected from that distribution, so ensure
    // there's enough feedstocks in total to cover random deviations.
    enum Moiety {
      case none
      case silylene
      case silicon
      case germanene
    }
    
    var baseAtoms: [MRAtom] = []
    var moietyAtoms: [MRAtom] = []
    var atoms: [MRAtom] { baseAtoms + moietyAtoms }
    var moiety: Moiety
    
    init(position: SIMD3<Float>, moiety: Moiety = .none) {
      self.baseAtoms = TripodAtomSource.global.atoms
      self.moiety = moiety
      
      for i in baseAtoms.indices {
        baseAtoms[i].origin += position
      }
    }
    
    mutating func detachMoiety() -> [MRAtom] {
      // If the atoms must be rotated a certain way, the caller should take care
      // of that.
      let output = moietyAtoms
      moietyAtoms = []
      moiety = .none
      return output
    }
    
    static func createPositions(radius: Float) -> [SIMD3<Float>] {
      var spacingH = Constant(.square) { .elemental(.gold) }
      spacingH *= Float(0.5).squareRoot()
      spacingH *= 3
      
      var vectorH: SIMD3<Float> = [1, 0, 0]
      var vectorK: SIMD3<Float> = [
        -Float(0.25).squareRoot(), 0, -Float(0.75).squareRoot()]
      vectorH *= spacingH
      vectorK *= spacingH
      
      let numTripods: Int = 125 // 500
      var positions: [SIMD3<Float>] = []
      var createdDictionary: [SIMD2<Int>: Bool] = [:]
      var randomBounds = Int(radius / spacingH)
      randomBounds *= 2
      
      for _ in 0..<numTripods {
        var attempts: Int = 0
        while true {
          attempts += 1
          if attempts > 100 {
            fatalError("Took too many attempts to create a tripod.")
          }
          
          let h = Int.random(in: -randomBounds...randomBounds)
          let k = Int.random(in: -randomBounds...randomBounds)
          let position = Float(h) * vectorH + Float(k) * vectorK
          guard (position * position).sum().squareRoot() < radius else {
            // The position fell outside of bounds.
            continue
          }
          
          let intVector = SIMD2(h, k)
          guard createdDictionary[intVector] == nil else {
            // The position was already taken.
            continue
          }
          createdDictionary[intVector] = true
          positions.append(position)
          break
        }
      }
      
      return positions
    }
  }
}

extension Bootstrapping {
  struct TripodAtomSource {
    static let global = TripodAtomSource()
    
    var atoms: [MRAtom] = []
    
    init() {
      // Create a lattice representing the tooltip.
      let lattice = Lattice<Cubic> { h, k, l in
        Bounds { 4 * h + 4 * k + 4 * l }
        Material { .elemental(.carbon) }
        
        Volume {
          Origin { 2 * h + 2 * k + 2 * l }
          Origin { 0.25 * (h + k - l) }
          
          // Remove the front plane.
          Convex {
            Origin { 0.25 * (h + k + l) }
            Plane { h + k + l }
          }
          
          func triangleCut(signPosition: Float, signPlanes: Float) {
            Convex {
              Origin { 0.25 * signPosition * (h - k - l) }
              Plane { signPlanes * (h - k - l) }
            }
            Convex {
              Origin { 0.25 * signPosition * (k - l - h) }
              Plane { signPlanes * (k - l - h) }
            }
            Convex {
              Origin { 0.25 * signPosition * (l - h - k) }
              Plane { signPlanes * (l - h - k) }
            }
          }
          
          // Remove some atoms on the front.
          Convex {
            triangleCut(signPosition: -1, signPlanes: -1)
          }
          
          // Remove the back plane.
          Convex {
            Origin { -0.25 * (h + k + l) }
            Plane { -(h + k + l) }
          }
          
          Replace { .empty }
          
          // Replace the top atom with germanium.
          Convex {
            Origin { 0.20 * (h + k + l) }
            Plane { h + k + l }
            
            Replace { .atom(.germanium) }
          }
        }
      }
      
      let tooltipLatticeAtoms = lattice.entities.map(MRAtom.init)
      
      let tooltipCarbons = tooltipLatticeAtoms.map {
        var copy = $0
        copy.element = 6
        return copy
      }
      var tooltipDiamondoid = Diamondoid(atoms: tooltipCarbons)
      tooltipDiamondoid.translate(offset: -tooltipDiamondoid.createCenterOfMass())
      let tooltipCenterOfMass = tooltipDiamondoid.createCenterOfMass()
      
      // The hydrogen connected to germanium has a higher elevation. Project
      // all the atoms onto a ray pointing from the center of mass toward (111),
      // then select the highest one. This is the germanium hydrogen. The carbon
      // with the greatest index is the germanium center.
      let tooltipDiamondoidAtomsHeight = tooltipDiamondoid.atoms.map {
        let delta = $0.origin - tooltipCenterOfMass
        let dotProduct = (delta * SIMD3(1, 1, 1)).sum()
        return dotProduct
      }
      var maxHydrogenHeight: Float = -.greatestFiniteMagnitude
      var maxCarbonHeight: Float = -.greatestFiniteMagnitude
      var maxHydrogenIndex: Int = -1
      var maxCarbonIndex: Int = -1
      for i in tooltipDiamondoid.atoms.indices {
        let atom = tooltipDiamondoid.atoms[i]
        let height = tooltipDiamondoidAtomsHeight[i]
        if atom.element == 6 {
          if height > maxCarbonHeight {
            maxCarbonHeight = height
            maxCarbonIndex = i
          }
        } else {
          if height > maxHydrogenHeight {
            maxHydrogenHeight = height
            maxHydrogenIndex = i
          }
        }
      }
      do {
        // Rescale the germanium hydrogen, change the germanium's element to Ge.
        let germanium = tooltipDiamondoid.atoms[maxCarbonIndex]
        let hydrogen = tooltipDiamondoid.atoms[maxHydrogenIndex]
        var delta = hydrogen.origin - germanium.origin
        let previousLength = (delta * delta).sum().squareRoot()
        let scaleFactor: Float = (1.5290 / 10) / previousLength
        delta = hydrogen.origin - germanium.origin
        delta *= scaleFactor
        
        let newOrigin = germanium.origin + delta
        tooltipDiamondoid.atoms[maxHydrogenIndex].origin = newOrigin
        tooltipDiamondoid.atoms[maxCarbonIndex].element = 32
        
        // Add a common offset to the hydrogen and germanium atoms.
        var commonOffset = SIMD3<Float>(1, 1, 1) / Float(3).squareRoot()
        commonOffset *= 0.030
        tooltipDiamondoid.atoms[maxHydrogenIndex].origin += commonOffset
        tooltipDiamondoid.atoms[maxCarbonIndex].origin += commonOffset
      }
      do {
        // Search for C-Ge bonds, then slightly offset carbons connected to Ge.
        // Also rescale any hydrogens connected to those carbons.
        for var bond in tooltipDiamondoid.bonds {
          var atom1 = tooltipDiamondoid.atoms[Int(bond[0])]
          var atom2 = tooltipDiamondoid.atoms[Int(bond[1])]
          guard atom1.element == 32 || atom2.element == 32,
                atom1.element != 1 && atom2.element != 1
          else {
            continue
          }
          if atom1.element == 32 {
            swap(&atom1, &atom2)
            bond = SIMD2(bond[1], bond[0])
          }
          
          var hydrogenIndices: [Int] = []
          for bond2 in tooltipDiamondoid.bonds {
            guard bond2[0] == bond[0] || bond2[1] == bond[0] else {
              continue
            }
            let atom3 = tooltipDiamondoid.atoms[Int(bond2[0])]
            let atom4 = tooltipDiamondoid.atoms[Int(bond2[1])]
            if atom3.element == 1 {
              hydrogenIndices.append(Int(bond2[0]))
            }
            if atom4.element == 1 {
              hydrogenIndices.append(Int(bond2[1]))
            }
          }
          
          var hydrogen1 = tooltipDiamondoid.atoms[hydrogenIndices[0]]
          var hydrogen2 = tooltipDiamondoid.atoms[hydrogenIndices[1]]
          
          var carbonDelta = atom1.origin - atom2.origin
          let planeVector = SIMD3<Float>(1, 1, 1) / Float(3).squareRoot()
          let dotProduct = (carbonDelta * planeVector).sum()
          carbonDelta -= planeVector * dotProduct
          
          let deltaLength = (carbonDelta * carbonDelta).sum().squareRoot()
          carbonDelta /= deltaLength
          carbonDelta *= 0.030
          
          atom1.origin += carbonDelta
          hydrogen1.origin += carbonDelta
          hydrogen2.origin += carbonDelta
          tooltipDiamondoid.atoms[Int(bond[0])] = atom1
          tooltipDiamondoid.atoms[hydrogenIndices[0]] = hydrogen1
          tooltipDiamondoid.atoms[hydrogenIndices[1]] = hydrogen2
        }
      }
      
      // Locate the three carbons most "far out" in each of 3 directions.
      // Replace the unwanted hydrogens with sulfurs and move outward. Use the
      // direction of the (111) plane and the center of mass to move the centers.
      //
      // Add functionality that lets you rotate the carbon and all bonded atoms.
      // This degree of freedom will be extremely useful when fitting to an
      // available site on the silicon surface.
      do {
        let directions = [
          SIMD3<Float>(1, -1, -1) / Float(3).squareRoot(),
          SIMD3<Float>(-1, 1, -1) / Float(3).squareRoot(),
          SIMD3<Float>(-1, -1, 1) / Float(3).squareRoot(),
        ]
        var maximumDistances: [Float] = [0, 0, 0]
        var maximumIndices: [Int] = [-1, -1, -1]
        for atomID in tooltipDiamondoid.atoms.indices {
          let atom = tooltipDiamondoid.atoms[atomID]
          guard atom.element == 6 else {
            continue
          }
          
          for lane in 0..<3 {
            let direction = directions[lane]
            let delta = atom.origin - tooltipCenterOfMass
            let distance = (delta * direction).sum()
            if distance > maximumDistances[lane] {
              maximumDistances[lane] = distance
              maximumIndices[lane] = atomID
            }
          }
        }
        
        // Iterate over the indices, fetching the direction corresponding to that
        // index. Use the direction to rotate the bonded atoms. Also, use the
        // vector (-1, -1, -1) to decide which hydrogen becomes sulfur.
        for directionID in directions.indices {
          let direction = directions[directionID]
          let atomID = maximumIndices[directionID]
          
          var bondedAtomIDs: [Int] = []
          for var bond in tooltipDiamondoid.bonds {
            guard Int(bond[0]) == atomID ||
                    Int(bond[1]) == atomID else {
              continue
            }
            if Int(bond[0]) == atomID {
              bond = SIMD2(bond[1], bond[0])
            }
            let bondedAtom = tooltipDiamondoid.atoms[Int(bond[0])]
            if bondedAtom.element != 6 {
              bondedAtomIDs.append(Int(bond[0]))
            }
          }
          bondedAtomIDs.sort(by: { atom1, atom2 in
            func getDotProduct(_ atomID: Int) -> Float {
              let atom = tooltipDiamondoid.atoms[atomID]
              let direction = SIMD3<Float>(1, 1, 1) / Float(3).squareRoot()
              return (atom.origin * direction).sum()
            }
            return getDotProduct(atom1) < getDotProduct(atom2)
          })
          
          let atom = tooltipDiamondoid.atoms[atomID]
          for i in bondedAtomIDs.indices {
            let bondedID = bondedAtomIDs[i]
            var other = tooltipDiamondoid.atoms[bondedID]
            
            let quaternion = Quaternion<Float>(angle: 0.11, axis: direction)
            var delta = other.origin - atom.origin
            delta = quaternion.act(on: delta)
            other.origin = atom.origin + delta
            
            // Change this atom to sulfur.
            if i == 0 {
              var delta = other.origin - atom.origin
              let deltaLength = (delta * delta).sum().squareRoot()
              let scaleFactor: Float = (1.814 / 10) / deltaLength
              delta *= scaleFactor
              other.origin = atom.origin + delta
              other.element = 16
            }
            tooltipDiamondoid.atoms[bondedID] = other
          }
        }
        
        var baseAtoms = tooltipDiamondoid.atoms
        
        // Don't set to the center of mass yet. If you do that, changing the
        // sulfur's position will change the entire object's position.
        let axis1 = cross_platform_normalize([1, 0, -1])
        let axis3 = cross_platform_normalize([1, 1, 1])
        let axis2 = cross_platform_cross(axis1, axis3)
        for i in baseAtoms.indices {
          var position = baseAtoms[i].origin
          let componentH = (position * SIMD3(axis1)).sum()
          let componentH2K = (position * SIMD3(axis2)).sum()
          let componentL = (position * SIMD3(axis3)).sum()
          position = SIMD3(componentH, componentL, componentH2K)
          baseAtoms[i].origin = position
        }
        
        var germaniumPosition: SIMD3<Float> = .zero
        for atom in baseAtoms {
          if atom.element == 32 {
            germaniumPosition = atom.origin
          }
        }
        
        let angle = Float(30 - 4) * .pi / 180
        let rotation = Quaternion(angle: angle, axis: [0, 1, 0])
        for i in baseAtoms.indices {
          baseAtoms[i].origin.x -= germaniumPosition.x
          baseAtoms[i].origin.y += 0.566
          baseAtoms[i].origin.z -= germaniumPosition.z
          baseAtoms[i].origin = rotation.act(on: baseAtoms[i].origin)
        }
        
        for i in baseAtoms.indices {
          var nearbyCarbons: [Int] = []
          var nearbyHydrogens: [Int] = []
          guard baseAtoms[i].element == 16 else {
            continue
          }
          
          let sulfur = baseAtoms[i]
          for j in baseAtoms.indices {
            let other = baseAtoms[j]
            guard other.element == 6 else {
              continue
            }
            let delta = other.origin - sulfur.origin
            let distance = (delta * delta).sum().squareRoot()
            if distance < 0.2 {
              nearbyCarbons.append(j)
            }
          }
          if nearbyCarbons.count == 1 {
            let carbon = baseAtoms[nearbyCarbons[0]]
            for j in baseAtoms.indices {
              let other = baseAtoms[j]
              guard other.element == 1 else {
                continue
              }
              let delta = other.origin - carbon.origin
              let distance = (delta * delta).sum().squareRoot()
              if distance < 0.15 {
                nearbyHydrogens.append(j)
              }
            }
          }
          
          var atomsToMove: [Int] = []
          atomsToMove.append(i)
          atomsToMove += nearbyCarbons
          atomsToMove += nearbyHydrogens
          for j in atomsToMove {
            baseAtoms[j].origin.y -= 0.010
          }
        }
        
        // Reverse the direction along `h` to match:
        // https://pubs.acs.org/doi/full/10.1021/prechem.3c00011
        for i in baseAtoms.indices {
          baseAtoms[i].x = -baseAtoms[i].x
        }
        
        self.atoms = baseAtoms
      }
    }
  }
}

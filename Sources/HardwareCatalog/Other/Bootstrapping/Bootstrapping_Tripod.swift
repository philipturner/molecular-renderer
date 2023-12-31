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
//    tripod. Make the tripod compress a little bit to animate how mechanical
//    force catalyzes chemical reactions in mechanosynthesis.
//    - Gather more points on the GFN potential energy surface. The number of
//      angstroms you'll animate it deforming may not be 1.0. Therefore, the
//      range of deformation may be larger, or the resolution should be higher
//      in a smaller range. Both require resampling GFN, which takes on the
//      order of 10 minutes. This script can reproduce the keyframes:
//      https://gist.github.com/philipturner/4e40f131ff711186400b7d6ccc171911
//      - Perhaps merge this with the other points below, so the tooltip isn't
//        isolated from the moieties. This would be more accurate and remove the
//        need for complex heuristics to decide the tripod depth. For the near
//        future, the 1-angstrom deformation with manual moiety placement should
//        suffice for debugging the code to script mechanosynthesis.
//    - Repeat a similar workflow to animate how the reactive species move
//      during the reaction, if GFN handles silicon radicals correctly. Keep the
//      germanium and three methyl groups attached to the germanium fixed.
//    - Use something similar to the above point to find the location of
//      moieties in general.
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
      
      var positions: [SIMD3<Float>] = []
      var createdDictionary: [SIMD2<Int>: Bool] = [:]
      do {
        let numTripods: Int = 500
        let randomBounds = Int(radius / spacingH)
        
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
            guard (position * position).sum().squareRoot() < radius / 2 else {
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
      }
      do {
        // Expand to 10000 tripods for the final animation. 4000 should be
        // plenty for debugging performance.
        let numTripods: Int = 4000
        let randomBounds = 2 * Int(radius / spacingH)
        
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
            guard (position * position).sum().squareRoot() > radius / 2,
                  (position * position).sum().squareRoot() < radius else {
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
      
      let tooltipLatticeAtoms = lattice.atoms.map(MRAtom.init)
      
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

extension Bootstrapping {
  struct TripodWarp {
    static var global = TripodWarp()
    
    // A dictionary for retrieving the atoms corresponding to a particular key.
    var lookupTable: [Float: [MRAtom]] = [:]
    
    // An array of keys for the lookup table, sorted in ascending order.
    var lookupTableKeys: [Float] = []
    
    init() {
      let lines = Self.rawText.split(separator: "\n").map(String.init)
      var startedXTB = false
      var currentXTBHeight: Float = 1000
      var currentXTBLines: [String] = []
      
      for var line in lines {
        if line.starts(with: "$height") {
          line.removeFirst("$height ".count)
          precondition(!startedXTB)
          precondition(currentXTBHeight == 1000)
          precondition(currentXTBLines.count == 0)
          
          guard let float = Float(line) else {
            fatalError("Could not convert float: \(line)")
          }
          currentXTBHeight = float
        } else if line.starts(with: "$coord") {
          line.removeFirst("$coord".count)
          precondition(!startedXTB)
          precondition(currentXTBHeight != 1000)
          precondition(currentXTBLines.count == 0)
          
          startedXTB = true
        } else if line.starts(with: "$end") {
          line.removeFirst("$end".count)
          precondition(startedXTB)
          precondition(currentXTBHeight != 1000)
          precondition(currentXTBLines.count > 0)
          
          let key = currentXTBHeight
          currentXTBHeight = 1000
          startedXTB = false
          
          var query: String = "$coord\n"
          for line in currentXTBLines {
            query += line + "\n"
          }
          query += "$end"
          currentXTBLines = []
          let value = importFromXTB(query)
          
          precondition(lookupTable[key] == nil)
          lookupTable[key] = value
          lookupTableKeys.append(key)
        } else if startedXTB {
          currentXTBLines.append(line)
        }
      }
      
      lookupTableKeys.sort { $0 < $1 }
    }
    
    // This may need to be changed to a different function signature, so it can
    // modify a tripod in-place.
    func createTripod(heightChange: Float) -> Tripod {
      var lowestKeyIndex = 0
      while true {
        if lookupTableKeys[lowestKeyIndex] > heightChange {
          lowestKeyIndex -= 1
          break
        }
        
        lowestKeyIndex += 1
        if lowestKeyIndex > lookupTableKeys.count - 1 {
          break
        }
      }
      
      var height1: Float
      var weight1: Float
      var height2: Float
      var weight2: Float
      if lowestKeyIndex == -1 {
        height1 = lookupTableKeys[0]
        height2 = lookupTableKeys[0]
        weight1 = 1
        weight2 = 0
      } else if lowestKeyIndex >= lookupTableKeys.count - 1 {
        height1 = lookupTableKeys[lookupTableKeys.count - 1]
        height2 = lookupTableKeys[lookupTableKeys.count - 1]
        weight1 = 1
        weight2 = 0
      } else {
        height1 = lookupTableKeys[lowestKeyIndex]
        height2 = lookupTableKeys[lowestKeyIndex + 1]
        let span = height2 - height1
        let progress = heightChange - height1
        weight1 = 1 - progress / span
        weight2 = progress / span
      }
      
      var tripod = Tripod(position: .zero)
      tripod.moietyAtoms = []
      guard let base1 = lookupTable[height1],
            let base2 = lookupTable[height2] else {
        fatalError("Could not search lookup table.")
      }
      tripod.baseAtoms = []
      for (atom1, atom2) in zip(base1, base2) {
        precondition(atom1.element == atom2.element)
        let origin1 = atom1.origin * weight1
        let origin2 = atom2.origin * weight2
        let atom = MRAtom(origin: origin1 + origin2, element: atom1.element)
        tripod.baseAtoms.append(atom)
      }
      
      return tripod
    }
    
    private static let rawText = """
    $height -9.998679e-06
    $coord
           -5.44558316745966        8.98327732617168        0.37604399882760      c
           -6.28653175009730        9.41882041578242        2.21029708384404      h
           -5.52300000000000        5.62700000000000        0.03100000000000      s
           -6.67033936093756        9.74684476835435       -1.10001770164250      h
            2.39726168417094        8.98334834142294       -4.90417434574730      c
            4.28800553860581        9.74670453191397       -5.22701370346933      h
            1.22921312667207        9.41860574650897       -6.54965170323884      h
            2.73500000000000        5.62700000000000       -4.79900000000000      s
           -1.52506780377720        9.39211564448013       -2.27142574385488      c
           -2.60904900077938       10.11749589385783       -3.87632830670467      h
           -1.58344827559761        7.32557392430825       -2.35687351583017      h
            1.57185626519822       10.21873977404363        2.33697447550425      c
           -1.20410379940041        9.39217192746192        2.45675131387147      c
           -2.05220185396183       10.11789625242512        4.19772747904787      h
           -1.24877766969295        7.32564503132273        2.55048176396032      h
           -2.80952939810030       10.21813057583709        0.19257249271154      c
            2.72969180548137        9.39232008793836       -0.18549618133180      c
            2.83276039205460        7.32577693285500       -0.19356758831446      h
            4.66161965805559       10.11757085020355       -0.32156579043490      h
            1.23822901713048       10.21905366430260       -2.52980216272537      c
            1.45729589723671       13.06428844700114       -2.99985256034839      c
            0.44708236781775       13.57063972260548       -4.72279779584288      h
            3.43170712647039       13.58648408711913       -3.27189709831667      h
           -3.32607866652374       13.06288595900179        0.23775950888728      c
           -4.31308720471191       13.56957253514903        1.97396580058775      h
           -4.54866355552598       13.58533401590120       -1.33616818258112      h
           -0.00000000000000       14.65699999999999       -0.00000000000000      ge
            0.00027287172182       17.52637666069576       -0.00021164346233      h
            3.04855897623189        8.98328204405391        4.52802842497603      c
            5.05765080373144        9.41828983572139        4.33913213523320      h
            2.78800000000000        5.62700000000000        4.76800000000000      s
            2.38288433083744        9.74696936302560        6.32678231637057      h
            1.86953494638244       13.06379467300590        2.76160086658508      c
            3.86674034544127       13.57016471582940        2.74801064025244      h
            1.11806519577141       13.58623096047975        4.60749153539689      h
    $end

    $height -0.010008992
    $coord
           -5.46098798397692        8.95877630241871        0.38111081920169      c
           -6.29610701646356        9.40473632349621        2.21571195517333      h
           -5.52300000000000        5.62700000000000        0.03100000000000      s
           -6.67784149612266        9.73544821611798       -1.09529495535412      h
            2.40011697528186        8.95875148264198       -4.92008708351079      c
            4.28692814214971        9.73580832753779       -5.23617736026344      h
            1.22845233537476        9.40451013294026       -6.56040787652971      h
            2.73500000000000        5.62700000000000       -4.79900000000000      s
           -1.52636323752013        9.32118886956789       -2.27203477391585      c
           -2.61024547581887       10.04692490050890       -3.87754492418712      h
           -1.58441527873061        7.25444036960093       -2.35922701125987      h
            1.57467863501957       10.14792570544048        2.34035902221439      c
           -1.20456343344898        9.32124481030680        2.45780860688999      c
           -2.05297260245739       10.04705459854777        4.19923934727052      h
           -1.25102642409426        7.25450666238616        2.55177893945963      h
           -2.81424203399291       10.14792470066496        0.19356868248295      c
            2.73051117951297        9.32113849911631       -0.18590657894570      c
            2.83479543799153        7.25435038481297       -0.19256768332498      h
            4.66292650869422       10.04670218186097       -0.32187497673702      h
            1.23930696187738       10.14801049339139       -2.53411414026130      c
            1.46451358494363       12.98374424720699       -3.00876877786196      c
            0.45577034355768       13.49945529123947       -4.72877129502216      h
            3.43830281077183       13.51157820979719       -3.26893445340141      h
           -3.33792102761625       12.98367505013088        0.23592943520089      c
           -4.32328621541594       13.49930553273489        1.96944090085938      h
           -4.55011499709349       13.51139327188857       -1.34341062308988      h
           -0.00000000000000       14.46800000000001       -0.00000000000000      ge
           -0.00009909156790       17.34843562611097       -0.00014773089366      h
            3.06051357685833        8.95873959317701        4.53870299259072      c
            5.06692506085271        9.40449576386827        4.34438054258540      h
            2.78800000000000        5.62700000000000        4.76800000000000      s
            2.39066574977899        9.73575194861855        6.33072540870981      h
            1.87330326069737       12.98366081242199        2.77268494669133      c
            3.86722152590514       13.49936353372975        2.75930425736688      h
            1.11153753480628       13.51143120781159        4.61207110420869      h
    $end

    $height -0.020007985
    $coord
           -5.47775721264771        8.93555037939501        0.38682964926519      c
           -6.30586858228515        9.39133796112711        2.22218022384729      h
           -5.52300000000000        5.62700000000000        0.03100000000000      s
           -6.68693286331374        9.72497104361637       -1.08952546322395      h
            2.40336012959030        8.93551348449104       -4.93746495878226      c
            4.28624462144284        9.72543399311255       -5.24693136083739      h
            1.22755159446582        9.39106153842763       -6.57210657256123      h
            2.73500000000000        5.62700000000000       -4.79900000000000      s
           -1.52762793723777        9.25241113749136       -2.27360069533882      c
           -2.61110463339533        9.97989603435885       -3.87927297441783      h
           -1.58575226728457        7.18591151988760       -2.36437863408858      h
            1.57842073650518       10.07916659484380        2.34480944793863      c
           -1.20520303024241        9.25302512186644        2.45954944920283      c
           -2.05396807565315        9.98020328727221        4.20087683018820      h
           -1.25434170782781        7.18654230554019        2.55531758509726      h
           -2.82002028215637       10.07918527783650        0.19431750629389      c
            2.73252596721028        9.25265747491460       -0.18631809555677      c
            2.83970918779350        7.18617100002524       -0.19145627422714      h
            4.66496216106142        9.97972178543956       -0.32193688544447      h
            1.24131204545011       10.07919071096282       -2.53951847960612      c
            1.47350819628670       12.90671522866745       -3.01902460630567      c
            0.46638871992914       13.43253206586944       -4.73584254966393      h
            3.44681483009801       13.43995549728587       -3.26600814240109      h
           -3.35138846270605       12.90671456245848        0.23330049244588      c
           -4.33482278345996       13.43234524865081        1.96386815444748      h
           -4.55207038480929       13.43969917029141       -1.35215438099214      h
           -0.00000000000000       14.27900000000001        0.00000000000000      ge
           -0.00009347037642       17.17388822778555        0.00009895268770      h
            3.07401953719929        8.93548726969971        4.55020871986178      c
            5.07762828658653        9.39095044376429        4.34955753759803      h
            2.78799999999999        5.62700000000000        4.76800000000000      s
            2.40040156521451        9.72533169645325        6.33553125354517      h
            1.87765799844995       12.90665225994591        2.78570651016043      c
            3.86811431881128       13.43225656913309        2.77233820612727      h
            1.10473571873253       13.43965845976286        4.61817045829095      h
    $end

    $height -0.03000698
    $coord
           -5.49490099804516        8.91240508983518        0.39324454748460      c
           -6.31455552698174        9.37757194745109        2.23015570000649      h
           -5.52300000000000        5.62700000000000        0.03100000000000      s
           -6.69736358922071        9.71478893657164       -1.08238344170454      h
            2.40700370144580        8.91241866533589       -4.95550535985017      c
            4.28613113139922        9.71491508911529       -5.25898568280276      h
            1.22601845855824        9.37762181312127       -6.58379237269812      h
            2.73500000000000        5.62700000000000       -4.79900000000000      s
           -1.52852534075182        9.18462227860698       -2.27442114355735      c
           -2.61201992700097        9.91120872501671       -3.88102897121560      h
           -1.58513851818527        7.11760500799109       -2.36623802358231      h
            1.58272383216922       10.01118916995512        2.34982841169917      c
           -1.20530166857465        9.18471961917724        2.46094658068789      c
           -2.05486406984529        9.91134980350225        4.20259088971190      h
           -1.25654499395503        7.11771303130209        2.55594789348690      h
           -2.82630120494233       10.01117021524550        0.19562278024659      c
            2.73399511127646        9.18464821534588       -0.18665293635447      c
            2.84187780671121        7.11763459557450       -0.18974104107481      h
            4.66708160520194        9.91127857904598       -0.32176583863947      h
            1.24377491647002       10.01110098589281       -2.54560305040156      c
            1.48374562423633       12.83156683216948       -3.02940853534507      c
            0.47761829081342       13.36894292486978       -4.74156482754204      h
            3.45612805511426       13.37083924949018       -3.26064869481535      h
           -3.36540201397697       12.83162648618138        0.22967000381908      c
           -4.34518292711544       13.36896057709841        1.95704640672643      h
           -4.55184137654034       13.37081082970792       -1.36288672656168      h
            0.00000000000000       14.09000000000001        0.00000000000001      ge
            0.00001022023624       17.00213717578119       -0.00000097726281      h
            3.08822705760833        8.91233760982468        4.56203736893766      c
            5.08892922769008        9.37713675443696        4.35318274563838      h
            2.78799999999999        5.62700000000001        4.76800000000000      s
            2.41184023778852        9.71502826872214        6.34119479184332      h
            1.88174013394922       12.83166681200722        2.79964643810618      c
            3.86757680502266       13.36903718847193        2.78439078057154      h
            1.09584521305809       13.37082402670489        4.62345610666420      h
    $end

    $height -0.04000597
    $coord
           -5.51415473149141        8.89135266354301        0.40105122139037      c
           -6.32439608340638        9.36393186093887        2.23994436093565      h
           -5.52300000000000        5.62700000000000        0.03100000000000      s
           -6.71035998103061        9.70563142065179       -1.07343178297342      h
            2.41000689034010        8.89140084306528       -4.97598534938530      c
            4.28504885354977        9.70570581035971       -5.27463449833940      h
            1.22258049093176        9.36410666198361       -6.59705821947000      h
            2.73500000000000        5.62700000000000       -4.79900000000000      s
           -1.53022483788276        9.11981441995916       -2.27703125474100      c
           -2.61298880167624        9.84807502124276       -3.88368504164231      h
           -1.58655339186617        7.05310393900928       -2.37264236430981      h
            1.58756178074104        9.94545402132493        2.35650147351174      c
           -1.20664076679980        9.11969620078408        2.46355027605811      c
           -2.05652944605875        9.84785161216968        4.20468641554089      h
           -1.26123999910674        7.05295142645789        2.56000852402367      h
           -2.83448208873803        9.94552787226473        0.19643963460203      c
            2.73689820489604        9.11965023289455       -0.18685230078033      c
            2.84773544608783        7.05289945216348       -0.18775783800904      h
            4.66970584667811        9.84784259095056       -0.32119059601215      h
            1.24708744368340        9.94555475340541       -2.55314335503172      c
            1.49551459919905       12.76061551500622       -3.04030771173011      c
            0.49120710406238       13.30992895088554       -4.74824882441045      h
            3.46727230422170       13.30476105755967       -3.25523341303167      h
           -3.38070152993469       12.76055837857716        0.22501124202941      c
           -4.35745558820491       13.30983725270854        1.94884962646008      h
           -4.55293294722700       13.30468715480428       -1.37497652164327      h
            0.00000000000000       13.90100000000000       -0.00000000000001      ge
            0.00001741720748       16.83598631460447       -0.00012104227043      h
            3.10443128130670        8.89132367529470        4.57499416204983      c
            5.10210512151086        9.36365983282978        4.35706353585596      h
            2.78800000000001        5.62700000000001        4.76800000000000      s
            2.42575106685805        9.70576946261798        6.34816780561542      h
            1.88529114519119       12.76050795364455        2.81523784847165      c
            3.86655055577575       13.30983158531594        2.79931234480140      h
            1.08565277515716       13.30461888233111        4.63035043125572      h
    $end

    $height -0.050004967
    $coord
           -5.53402701187567        8.87102805485788        0.41001699106956      c
           -6.33371677294936        9.35076519415991        2.25173513167287      h
           -5.52300000000000        5.62700000000000        0.03100000000000      s
           -6.72437726938524        9.69756630661464       -1.06272568519794      h
            2.41188259659225        8.87101163110510       -4.99787617555069      c
            4.28239379096290        9.69777306971185       -5.29230992982688      h
            1.21667121372758        9.35067908844504       -6.61125645927057      h
            2.73500000000000        5.62700000000000       -4.79900000000000      s
           -1.53078024033749        9.05499485277508       -2.27911762960414      c
           -2.61304259118651        9.78360693530292       -3.88652332064312      h
           -1.58529851358538        6.98835885619688       -2.37745408204549      h
            1.59200924025365        9.88187451530854        2.36384305582525      c
           -1.20837038936035        9.05493347942474        2.46546796978133      c
           -2.05915062240189        9.78334682701854        4.20658605339892      h
           -1.26616033905169        6.98827532348972        2.56166446737234      h
           -2.84313942897460        9.88189814762240        0.19683393872909      c
            2.73916170813176        9.05497498965554       -0.18633167148098      c
            2.85160261304942        6.98834266311291       -0.18444049625890      h
            4.67230382994134        9.78361895349839       -0.32028492678558      h
            1.25123919943280        9.88197178878600       -2.56084755285863      c
            1.50961265445593       12.69342265379937       -3.05093156096461      c
            0.50669198277506       13.25629429550366       -4.75355850284860      h
            3.48088272285677       13.24223359784735       -3.24682318488416      h
           -3.39686755345194       12.69331941145989        0.21815716092587      c
           -4.37004244985593       13.25612935211051        1.93799717755490      h
           -4.55205062977808       13.24215292886634       -1.39111389024351      h
           -0.00000000000002       13.71200000000001       -0.00000000000000      ge
            0.00002483085942       16.67377904679715        0.00001704028765      h
            3.12226125314893        8.87096173508999        4.58749318784421      c
            5.11713793841341        9.35037817297337        4.35898645289851      h
            2.78800000000000        5.62700000000000        4.76800000000001      s
            2.44224781392416        9.69783353666748        6.35467231651734      h
            1.88726901844372       12.69329645754164        2.83277051061520      c
            3.86322100984299       13.25620816506108        2.81551555911511      h
            1.07128920050650       13.24203681328658        4.63791905769649      h
    $end

    $height -0.060003962
    $coord
           -5.55567353540701        8.85231112777287        0.42071369187894      c
           -6.34177575764187        9.33818552742596        2.26639937224871      h
           -5.52300000000000        5.62700000000000        0.03100000000000      s
           -6.74149257245080        9.69127831869095       -1.04873536980557      h
            2.41355345314115        8.85228923986029       -5.02192056400157      c
            4.27900586613157        9.69125643905515       -5.31435301878976      h
            1.20801931228734        9.33798081002566       -6.62545476470274      h
            2.73500000000000        5.62700000000000       -4.79900000000000      s
           -1.53230633372970        8.99428249855103       -2.28243405238804      c
           -2.61426624895076        9.72183133709244       -3.89090491626036      h
           -1.58397814971566        6.92775188543566       -2.38305020873772      h
            1.59751980160571        9.82074464643951        2.37267286662102      c
           -1.21036745862386        8.99324015425204        2.46810552970734      c
           -2.06225921229755        9.72085249785223        4.20939160419977      h
           -1.27163109417248        6.92674509900333        2.56297764952263      h
           -2.85360321594300        9.82085809069708        0.19717116373332      c
            2.74270944369690        8.99366742333175       -0.18590599006236      c
            2.85549859850976        6.92714820246189       -0.18026240274630      h
            4.67670229258914        9.72115715180790       -0.31862320543308      h
            1.25620144640313        9.82082776878654       -2.57000793235228      c
            1.52643034601042       12.63092946604332       -3.06054954313356      c
            0.52796857016604       13.20830670943773       -4.75921771412172      h
            3.49756965881675       13.18212352591800       -3.23690200155818      h
           -3.41361192729581       12.63097437156558        0.20849476148606      c
           -4.38541348119217       13.20851183693467        1.92247705656819      h
           -4.55178083731923       13.18222861639584       -1.41046703698467      h
            0.00000000000001       13.52299999999999       -0.00000000000001      ge
            0.00000772923870       16.51865839913593       -0.00034950708465      h
            3.14236534354762        8.85225998373580        4.60084227196370      c
            5.13386778266689        9.33784381647610        4.35850110963871      h
            2.78799999999999        5.62699999999999        4.76800000000000      s
            2.46305983969600        9.69170112127376        6.36244554886198      h
            1.88729755084665       12.63088886400349        2.85195221233097      c
            3.85752076783404       13.20851642697056        2.83625161105133      h
            1.05448671200480       13.18231759417910        4.64712137147340      h
    $end

    $height -0.07000296
    $coord
           -5.57920167774637        8.83518396552671        0.43279043366100      c
           -6.34841858591649        9.32578593047875        2.28388276898654      h
           -5.52300000000000        5.62700000000000        0.03100000000000      s
           -6.76382141813667        9.68548056620220       -1.03104823489874      h
            2.41485708374108        8.83518985950129       -5.04831091161916      c
            4.27483041076993        9.68563059532844       -5.34222560603588      h
            1.19641156584364        9.32578223000414       -6.64004059707120      h
            2.73500000000000        5.62700000000000       -4.79900000000000      s
           -1.53444688782190        8.93428048563292       -2.28579865571004      c
           -2.61544333662691        9.66058142673057       -3.89595679226609      h
           -1.58165848292121        6.86818505652838       -2.38789877312883      h
            1.60430846406748        9.76239981322668        2.38272387400081      c
           -1.21210906374098        8.93438996878063        2.47172678422539      c
           -2.06588862286329        9.66084429437378        4.21300388261129      h
           -1.27703784832527        6.86830661143968        2.56377878088379      h
           -2.86555964854393        9.76237251088103        0.19779109533508      c
            2.74673456189695        8.93432548757414       -0.18618262522435      c
            2.85887560747849        6.86823840208896       -0.17598265086749      h
            4.68162997965832        9.66072613833894       -0.31728893642744      h
            1.26149333911250        9.76243500983804       -2.58076039624297      c
            1.54555536056773       12.57404387071678       -3.06816060462673      c
            0.55227832588865       13.16925381530114       -4.76185074165477      h
            3.51678631896737       13.12690823279082       -3.22092399425588      h
           -3.42980988354307       12.57395383372487        0.19542207399462      c
           -4.39995893551212       13.16919764243130        1.90244009007261      h
           -4.54768908428384       13.12676133650760       -1.43537403537225      h
           -0.00000000000001       13.33400000000003       -0.00000000000000      ge
            0.00016157109769       16.37300103124298       -0.00023622018155      h
            3.16468678100825        8.83510621616489        4.61523500659449      c
            5.15246329166971        9.32530945015127        4.35570126311253      h
            2.78800000000002        5.62699999999999        4.76800000000000      s
            2.48949436775130        9.68578335195089        6.37296897189469      h
            1.88438997078441       12.57399472303187        2.87251717692404      c
            3.84777991403325       13.16925771523646        2.85904375084755      h
            1.03114906256845       13.12678210041867        4.65609455030953      h
    $end

    $height -0.08000194
    $coord
           -5.60320620865583        8.81916721569533        0.45055693522883      c
           -6.35287036316103        9.31240598941081        2.30845568766436      h
           -5.52300000000000        5.62700000000000        0.03100000000000      s
           -6.78723475436019        9.68372036848826       -1.00513739877755      h
            2.41158910087924        8.81919179322894       -5.07792436965290      c
            4.26425138241708        9.68384399237115       -5.37534311926902      h
            1.17750255427645        9.31247550118884       -6.65614199876532      h
            2.73500000000000        5.62700000000000       -4.79900000000000      s
           -1.53511272659815        8.87492761512536       -2.29041242496507      c
           -2.61676064846948        9.59595527780327       -3.90347853101509      h
           -1.57482787046750        6.80901257318009       -2.39238115361950      h
            1.60933592499865        9.70681419441142        2.39431381739714      c
           -1.21578753987094        8.87506056107760        2.47460647644026      c
           -2.07185169842227        9.59619906580562        4.21786107960788      h
           -1.28431327677997        6.80914681683328        2.56004491374174      h
           -2.87812388262202        9.70684220135126        0.19631535996559      c
            2.75119112007967        8.87498064980018       -0.18442683895022      c
            2.85938671108828        6.80906446367949       -0.16780825161978      h
            4.68894524434818        9.59606681718416       -0.31462943461616      h
            1.26907896424227        9.70678655289022       -2.59085365427690      c
            1.57068825390577       12.52264242861017       -3.07178837197605      c
            0.58497065363403       13.13802114866034       -4.76087370304844      h
            3.54296146369356       13.07364330337550       -3.19780805126848      h
           -3.44558910302058       12.52268409203462        0.17545255758517      c
           -4.41559537031592       13.13809419405337        1.87359011276279      h
           -4.54080288571852       13.07354301738384       -1.46966350029799      h
           -0.00000000000000       13.14500000000000       -0.00000000000001      ge
           -0.00005247598325       16.23576370307592       -0.00007174596242      h
            3.19205816835432        8.81909697785062        4.62717336510750      c
            5.17594470864418        9.31194501912033        4.34726114866166      h
            2.78800000000002        5.62700000000001        4.76799999999999      s
            2.52368826826548        9.68399572704018        6.38036504283637      h
            1.87501813662646       12.52267043537257        2.89609511472813      c
            3.83064098068868       13.13811615278759        2.88689591262174      h
            0.99806509587400       13.07357115093388        4.66719737827440      h
    $end

    $height -0.090000935
    $coord
           -5.62717204720582        8.80512627410279        0.47457854492426      c
           -6.34925919242841        9.29691555968127        2.34334202245385      h
           -5.52300000000000        5.62700000000000        0.03100000000000      s
           -6.81721440144828        9.68433501034140       -0.96723156920338      h
            2.40259348877119        8.80511259292817       -5.11087066742071      c
            4.24618686864611        9.68450804118419       -5.42047540941022      h
            1.14525412614281        9.29678042993048       -6.67063160756480      h
            2.73500000000000        5.62700000000000       -4.79900000000000      s
           -1.53635485411367        8.81953087273563       -2.29552313390493      c
           -2.61773529456465        9.53577858651267       -3.91089290285478      h
           -1.56706380474466        6.75428102329280       -2.39829401802838      h
            1.61484991516071        9.65565433448519        2.40725162998939      c
           -1.21945594388189        8.81961300996492        2.47808970129089      c
           -2.07748520561507        9.53608042434217        4.22232878355555      h
           -1.29322543649935        6.75437452744384        2.55622229317817      h
           -2.89211485892586        9.65572773938005        0.19444365614097      c
            2.75606495862151        8.81951197280075       -0.18313543315222      c
            2.86049566652314        6.75426590172755       -0.15834512304736      h
            4.69568150523025        9.53585017116178       -0.31198803884359      h
            1.27761065854581        9.65574893720854       -2.60222043765063      c
            1.60615366093847       12.47874655994646       -3.06955354557613      c
            0.63655847474351       13.11907773324177       -4.75674577345088      h
            3.58191367728939       13.01792167228434       -3.16366575783544      h
           -3.46129499644678       12.47870744898339        0.14357075351454      c
           -4.43777228498346       13.11897123383536        1.82680854561360      h
           -4.53058078112555       13.01784695117326       -1.52050519065470      h
            0.00000000000001       12.95699999999997        0.00000000000001      ge
            0.00009804565057       16.11806527614273       -0.00025386097672      h
            3.22506990280248        8.80499857283827        4.63571305478309      c
            5.20458798993679        9.29621812305453        4.32625227109659      h
            2.78800000000005        5.62699999999999        4.76799999999996      s
            2.57185174110967        9.68470294808119        6.38713883176548      h
            1.85536889333637       12.47863976154655        2.92555634346009      c
            3.80131371791284       13.11899383302368        2.92929003830764      h
            0.94907420678252       13.01777140955487        4.68372814648420      h
    $end

    $height -0.099999934
    $coord
           -5.64796940770019        8.79167806729493        0.51035123058620      c
           -6.33261552214026        9.27503485483052        2.39488922351953      h
           -5.52300000000000        5.62700000000000        0.03100000000000      s
           -6.85532554204968        9.68720719952479       -0.90651997490113      h
            2.38256041573408        8.79154237421333       -5.14741103460337      c
            4.21335445433205        9.68706632132074       -5.48380259635916      h
            1.09240374580221        9.27475842204908       -6.68235682449358      h
            2.73500000000000        5.62700000000000       -4.79900000000000      s
           -1.53811558368019        8.76407625607774       -2.30073709911483      c
           -2.61883604536032        9.47138793227193       -3.91958536183726      h
           -1.55354555857655        6.69888262278435       -2.39970231524319      h
            1.62009764914312        9.60764603759342        2.42066930963321      c
           -1.22258161240400        8.76403700640011        2.48281424453174      c
           -2.08317613218872        9.47160581725546        4.22858793824257      h
           -1.30061016778779        6.69886516709301        2.54589051100101      h
           -2.90578204726926        9.60744556490484        0.19209205174805      c
            2.76094701418159        8.76426779944880       -0.18278695308683      c
            2.85459624430306        6.69906948290708       -0.14680880485207      h
            4.70309348235023        9.47191936851099       -0.31028029148266      h
            1.28688941525197        9.60792323839968       -2.61401068193419      c
            1.65856452712293       12.44014701089210       -3.05557160249215      c
            0.71771429061435       13.11631539675675       -4.74325368394903      h
            3.64163907294133       12.95246467351708       -3.10681972513221      h
           -3.47443052396863       12.43960758941949        0.09080315462643      c
           -4.46596502669537       13.11585072142644        1.74916662222002      h
           -4.51005590493152       12.95187467583954       -1.60114930939904      h
           -0.00000000000004       12.76800000000002       -0.00000000000001      ge
            0.00011817615044       16.01948454297552       -0.00024695748873      h
            3.26662144603081        8.79145702670473        4.63620851305986      c
            5.24088975815186        9.27450611489130        4.28489753339256      h
            2.78799999999997        5.62699999999996        4.76799999999998      s
            2.64444335927069        9.68696090453118        6.39057895279858      h
            1.81667198727191       12.43981872496873        2.96365898857641      c
            3.74858989793192       13.11621266072470        2.99236497776902      h
            0.86979111440417       12.95196018565741        4.70685008190282      h
    $end
    """
  }
}

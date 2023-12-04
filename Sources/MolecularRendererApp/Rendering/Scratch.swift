// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MolecularRenderer
import Numerics
import QuaternionModule

struct SimpleMechanosynthesis {
  var provider: MRAtomProvider
  
  init() {
    // This is a plan for how to approach the project. Upon initial creation, it
    // was expected to take multiple days.
    //
    // Design of tooltip:
    // - Create a lattice of non-carbon atoms.
    // - Map the non-carbon atoms to carbons before entering into 'Diamondoid'.
    // - Perform an O(n^2) search to find the new locations.
    // - Extract the atom positions and convert non-carbons to carbons.
    // - Remove hydrogens connected to the carbon that will gain a sulfur bond,
    //   rescale the hydrogen connected to Ge.
    // - Generate the sulfur atoms manually, instead of using the HDL.
    //
    // Design of surface:
    // - Create a diamond (111) surface, insert into the correct position
    //   relative to the adamantane tooltip, then run through the same geometry
    //   patching procedure.
    // - Convert atoms that came from the surface to silicon atoms. Rescale to
    //   match the different lattice constant, while keeping the center of mass
    //   the same.
    // - Remove passivating hydrogens that overlap the tooltip's sulfurs.
    //   Rescale the other hydrogens to match the Si-H bond length.
    //
    // Design of feedstock:
    // - Run everything above through xTB. Once you've confirmed it's
    //   kinetically stable, continue with geometry design.
    // - Replace the hydrogen with an acetylene radical, change the GFN commands
    //   to recognize the unpaired electron.
    // - Create a raw adamantane molecule. Perform some geometry optimizations
    //   with certain parts' positions constrained. Ensure the covalent bond
    //   transfers from the adamantane to the tooltip.
    //
    // Design of workpiece:
    // - Decide whether to use diamond or silicon for the AFM probe.
    // - Embed the adamantane into the AFM tip, decide where to stop simulating
    //   in atomic detail and place anchors.
    // - Confirm the hydrogen abstraction reaction succeeds.
    // - Create a set of animated keyframes, duplicating as necessary to target
    //   the traditional 120 Hz resolution. Alternatively, run a very long
    //   simulation at 120 Hz resolution and save to MRSim.
    // - Publish an animation.
    //
    // Other notes:
    // - Make the entire contraption have threefold symmetry, so it can be
    //   simulated faster with DFT. Not sure this particular instance will
    //   trigger the symmetry recognition in whatever software package simulates
    //   it. However, this is a good practice to establish.
    
    // MARK: - Tooltip
    
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
    provider = ArrayAtomProvider(tooltipLatticeAtoms)
    
    let tooltipCarbons = tooltipLatticeAtoms.map {
      var copy = $0
      copy.element = 6
      return copy
    }
    var tooltipDiamondoid = Diamondoid(atoms: tooltipCarbons)
    tooltipDiamondoid.translate(offset: -tooltipDiamondoid.createCenterOfMass())
    let tooltipCenterOfMass = tooltipDiamondoid.createCenterOfMass()
    provider = ArrayAtomProvider(tooltipDiamondoid.atoms)
    
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
          
          let quaternion = Quaternion<Float>(angle: 0.8, axis: direction)
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
    }
    
    // Print all the bonds in the molecule, which type they are, and how their
    // length deviates from the ideal value. Except for C-C and C-H bonds that
    // are almost in equilibrium.
    for bond in tooltipDiamondoid.bonds {
      let atom1 = tooltipDiamondoid.atoms[Int(bond[0])]
      let atom2 = tooltipDiamondoid.atoms[Int(bond[1])]
      let delta = atom2.origin - atom1.origin
      let bondLength = (delta * delta).sum().squareRoot()
      
      var idealBondLength: Float
      if (atom1.element == 1 || atom1.element == 6),
         (atom2.element == 1 || atom2.element == 6) {
        switch (atom1.element, atom2.element) {
        case (1, 6), (6, 1): idealBondLength = 1.1120
        case (6, 6): idealBondLength = 1.5270
        default: fatalError("Unexpected bonding configuration.")
        }
        idealBondLength /= 10
        if (idealBondLength - bondLength).magnitude < 0.003 {
          continue
        }
      } else {
        switch (atom1.element, atom2.element) {
        case (1, 32), (32, 1): idealBondLength = 1.529
        case (6, 32), (32, 6): idealBondLength = 1.949
        case (6, 16), (16, 6): idealBondLength = 1.814
        default: fatalError("Unexpected bonding configuration.")
        }
        idealBondLength /= 10
        if (idealBondLength - bondLength).magnitude < 0.0001 {
          continue
        }
      }
      
      func atomLabel(_ element: UInt8) -> String {
        switch element {
        case 1: return "H"
        case 6: return "C"
        case 14: return "Si"
        case 16: return "S"
        case 32: return "Ge"
        default: fatalError("Unrecognized element.")
        }
      }
      var label: String = ""
      label += atomLabel(atom1.element)
      label += "-"
      label += atomLabel(atom2.element)
      label += " \((idealBondLength - bondLength).magnitude)"
//      print(label)
    }
    
    provider = ArrayAtomProvider(tooltipDiamondoid.atoms)
    
    // MARK: - Surface
    
    // Create a diamond (111) surface.
    let surfaceLattice = Lattice<Cubic> { h, k, l in
      Bounds { 10 * h + 10 * k + 10 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 5 * (h + k + l) }
        Plane { h + k + l }
        
        Convex {
          Origin { -0.25 * (h + k + l) }
          Plane { -(h + k + l) }
        }
        for direction in [h, k, l] {
          for multiplier in [Float(0.50), -0.75] {
            Convex {
              Origin { multiplier * direction }
              Plane { multiplier * direction }
            }
          }
        }
        
        Replace { .empty }
        
        // The back row must be converted into free radicals to minimize the
        // atom count. Accomplish this by marking the back row with nitrogens.
        // These atoms will eventually be held stationary when we simulate the
        // trajectory.
        Convex {
          Origin { -0.00 * (h + k + l) }
          Plane { -(h + k + l) }
          
          Replace { .atom(.nitrogen) }
        }
      }
    }
    let surfaceAtoms = surfaceLattice.entities.map(MRAtom.init)
    let surfaceCarbonAtoms = surfaceAtoms.map {
      var copy = $0
      copy.element = 6
      return copy
    }
    var surfaceDiamondoid = Diamondoid(atoms: surfaceCarbonAtoms)
    let surfaceCenterOfMass = surfaceDiamondoid.createCenterOfMass()
    
    // Map the surface to silicon and record the number of unpaired electrons.
    // This should equal the number of nitrogens; take special care to not
    // delete hydrogens elevated above a certain point.
    var hydrogensToRemove: [Int] = []
    var anchors: [Int] = []
    for i in surfaceAtoms.indices {
      let atomI = surfaceAtoms[i]
      var closestDistance: Float = .greatestFiniteMagnitude
      var closestIndex: Int = -1
      for j in surfaceDiamondoid.atoms.indices {
        let atomJ = surfaceDiamondoid.atoms[j]
        let delta = atomI.origin - atomJ.origin
        let distance = (delta * delta).sum().squareRoot()
        if distance < closestDistance {
          closestDistance = distance
          closestIndex = j
        }
      }
      
      let index = closestIndex
      guard index != -1 else {
        fatalError("Index not correct.")
      }
      
      // Change the atom's identity to silicon.
      surfaceDiamondoid.atoms[index].element = 14
      
      var bondedHydrogenIDs: [Int] = []
      for var bond in surfaceDiamondoid.bonds {
        guard Int(bond[0]) == index || Int(bond[1]) == index else {
          continue
        }
        if Int(bond[0]) == index {
          bond = SIMD2(bond[1], bond[0])
        }
        if surfaceDiamondoid.atoms[Int(bond[0])].element != 1 {
          continue
        }
        bondedHydrogenIDs.append(Int(bond[0]))
      }
      
      // If there are no bonded hydrogens, return early.
      if bondedHydrogenIDs.count == 0 {
        continue
      }
      
      bondedHydrogenIDs.sort(by: { index1, index2 in
        let atom1 = surfaceDiamondoid.atoms[index1]
        let atom2 = surfaceDiamondoid.atoms[index2]
        return (
          (atom1.origin * SIMD3(1, 1, 1)).sum() <
          (atom2.origin * SIMD3(1, 1, 1)).sum()
        )
      })
      
      // For front atoms, the bonded hydrogen points toward (111).
      do {
        var delta =
        surfaceDiamondoid.atoms[bondedHydrogenIDs.last!].origin -
        surfaceDiamondoid.atoms[index].origin
        delta /= (delta * delta).sum().squareRoot()
        if (delta * SIMD3(1, 1, 1)).sum() > 0.800 {
          continue
        }
      }
      
      hydrogensToRemove.append(bondedHydrogenIDs[0])
      anchors.append(index)
    }
    surfaceDiamondoid.translate(offset: -surfaceCenterOfMass)
    
    // Rescale the bonds, now that the center of mass is the origin.
    for index in surfaceDiamondoid.atoms.indices {
      var atom = surfaceDiamondoid.atoms[index]
      if atom.element == 1 {
        continue
      }
      
      var bondedHydrogenIDs: [Int] = []
      for var bond in surfaceDiamondoid.bonds {
        guard Int(bond[0]) == index || Int(bond[1]) == index else {
          continue
        }
        if Int(bond[0]) == index {
          bond = SIMD2(bond[1], bond[0])
        }
        if surfaceDiamondoid.atoms[Int(bond[0])].element != 1 {
          continue
        }
        bondedHydrogenIDs.append(Int(bond[0]))
      }
      
      // Record the delta between each hydrogen.
      var hydrogenDeltas: [SIMD3<Float>] = []
      for hydrogenID in bondedHydrogenIDs {
        let hydrogen = surfaceDiamondoid.atoms[hydrogenID]
        var delta = hydrogen.origin - atom.origin
        let deltaLength = (delta * delta).sum().squareRoot()
        delta /= deltaLength
        hydrogenDeltas.append(delta * 1.483 / 10)
      }
      
      // Map the silicon to the new position.
      let scaleFactor: Float =
      Constant(.square) { .elemental(.silicon) } /
      Constant(.square) { .elemental(.carbon) }
      atom.origin *= scaleFactor
      surfaceDiamondoid.atoms[index] = atom
      
      // Bring the hydrogen(s) along with the silicon.
      for lane in bondedHydrogenIDs.indices {
        let hydrogenID = bondedHydrogenIDs[lane]
        var hydrogen = surfaceDiamondoid.atoms[hydrogenID]
        hydrogen.origin = atom.origin + hydrogenDeltas[lane]
        surfaceDiamondoid.atoms[hydrogenID] = hydrogen
      }
    }
    
    // Push the tooltip forward, so it rests just over the surface.
    tooltipDiamondoid.translate(
      offset: 0.470 * SIMD3<Float>(1, 1, 1) / Float(3).squareRoot())
    tooltipDiamondoid.rotate(
      angle: Quaternion<Float>(
        angle: 0.06 * 3.141592,
        axis: SIMD3<Float>(1, 1, 1) / Float(3).squareRoot()))
    
    // Record the closest silicon-sulfur bond while placing the tooltip. Record
    // its length and angle from (111) in degrees. Report the C-S-Si angle too.
    // Use trial and error to find the ideal position on the surface. Remove
    // the hydrogen attached to the silicon and remap the bond topology. Then,
    // it is ready to validate in xTB.
    
    var replacedHydrogens: [Int] = []
    for tooltipAtomID in tooltipDiamondoid.atoms.indices {
      let sulfur = tooltipDiamondoid.atoms[tooltipAtomID]
      guard sulfur.element == 16 else {
        continue
      }
      
      var minimumDistance: Float = .greatestFiniteMagnitude
      var minimumIndex: Int = -1
      for atomID in surfaceDiamondoid.atoms.indices {
        let silicon = surfaceDiamondoid.atoms[atomID]
        guard silicon.element == 14 else {
          continue
        }
        let delta = silicon.origin - sulfur.origin
        let distance = (delta * delta).sum().squareRoot()
        if distance < minimumDistance {
          minimumDistance = distance
          minimumIndex = atomID
        }
      }
      
      // Remove the upward-facing hydrogen; report angles with any other atoms.
      var bondedAtoms: [(index: Int, atom: MRAtom)] = []
      for var bond in surfaceDiamondoid.bonds {
        guard Int(bond[0]) == minimumIndex || Int(bond[1]) == minimumIndex else {
          continue
        }
        if Int(bond[0]) == minimumIndex {
          bond = SIMD2(bond[1], bond[0])
        }
        let neighbor = surfaceDiamondoid.atoms[Int(bond[0])]
        bondedAtoms.append((Int(bond[0]), neighbor))
      }
      bondedAtoms.sort(by: {
        let dot1 = ($0.atom.origin * SIMD3(1, 1, 1)).sum()
        let dot2 = ($1.atom.origin * SIMD3(1, 1, 1)).sum()
        return dot1 > dot2
      })
      replacedHydrogens.append(bondedAtoms.first!.index)
      
      // Report deviation from ideal geometry.
      let silicon = surfaceDiamondoid.atoms[minimumIndex]
      var siSDelta = sulfur.origin - silicon.origin
      let siSBondLength = (siSDelta * siSDelta).sum().squareRoot()
      siSDelta /= siSBondLength
      print("Si-S bond:", siSBondLength - 2.16 / 10)
      
      for bondedAtom in bondedAtoms[1...] {
        let first = bondedAtoms[0]
        guard first.atom.element == 1 else {
          fatalError("Unrecognized first bonded atom.")
        }
        let second = bondedAtom
        guard second.atom.element == 1 || second.atom.element == 14 else {
          fatalError("Unrecognized second bonded atom.")
        }
        
        // Units: rad -> degree
        var siSiDelta = second.atom.origin - silicon.origin
        siSiDelta /= (siSiDelta * siSiDelta).sum().squareRoot()
        let cosine = (siSDelta * siSiDelta).sum()
        var angle = Float.acos(cosine)
        angle *= 180 / 3.141592653
        
        var message: String = ""
        if second.atom.element == 1 {
          message += " H-Si-S"
        } else {
          message += "Si-Si-S"
        }
        message += " angle: "
        message += String(format: "%.2f", angle - (180 - 70.528779))
        
        print(message)
      }
    }
    hydrogensToRemove.append(contentsOf: replacedHydrogens)
    
    // Defer the removal of hydrogens until you discard the bonding topology.
    hydrogensToRemove.sort()
    anchors.sort()
    for i in hydrogensToRemove.reversed() {
      surfaceDiamondoid.atoms.remove(at: i)
      for anchorID in anchors.indices {
        if i < anchors[anchorID] {
          anchors[anchorID] -= 1
        }
      }
    }
    
    // Change the anchors. Only the 3 outermost radical atoms should be
    // constrained. This gives the inner atoms more room to adapt to the
    // hydrogens' Pauli repulsion. It results in a very conservative estimate
    // of stiffness. However, now that atoms can actually contribute to the
    // simulation, instead of wasting compute power.
    anchors.removeAll(where: { index in
      let atom = surfaceDiamondoid.atoms[index]
      let delta = atom.origin - .zero
      if (delta * delta).sum().squareRoot() < 0.25 {
        return true
      } else {
        return false
      }
    })
    print()
    print(
      "atoms:",
      surfaceDiamondoid.atoms.count, "(surface) +",
      tooltipDiamondoid.atoms.count, "(tooltip) =",
      // eventually, add the workpiece here
      surfaceDiamondoid.atoms.count + tooltipDiamondoid.atoms.count)
    print(
      "unpaired electrons:",
      hydrogensToRemove.count - replacedHydrogens.count)
    print(
      "anchors:",
      anchors.map { $0 + 1 })
    provider = ArrayAtomProvider([surfaceDiamondoid, tooltipDiamondoid])
    
    // MARK: - Simulation
    
//    print(exportToXTB(surfaceDiamondoid.atoms))
         print(exportToXTB([surfaceDiamondoid, tooltipDiamondoid]))
        #if true
        var minimized = importFromXTB(xtbText)
        minimized = minimized.map {
          var copy = $0
          copy.origin += SIMD3(1, 0, -1)
          return copy
        }
        provider = ArrayAtomProvider(
          surfaceDiamondoid.atoms +
          tooltipDiamondoid.atoms +
          minimized)
        #endif
  }
}

fileprivate let xtbText = """
$coord
        2.62822876030066       -2.21172196967269       -2.37969220280360      si
       -3.13691023003335        3.13790719131804       -3.31338885955427      si
        2.95500000000108        2.95500000000003       -7.30799999999890      si
        4.42521888810655        4.65485695961784       -8.97989254825987      h
       -0.36769334414354        5.45369019487105       -5.97196571296181      si
       -2.02844621850132        6.12184659015700       -8.11924812428409      h
       -0.01143341896473        7.95947268133861       -4.76907988045431      h
        5.30172550404049        0.19976503947437       -4.92407963757327      si
        7.09948290491001       -1.09320549651707       -6.60482120137705      h
       -2.29336370701247       -2.94747886933030        1.67975851103261      si
        2.95499999999887       -7.30800000000156        2.95500000000020      si
        5.26621344123946       -8.13629115215489        4.30620491510530      h
        0.29457070635645       -4.46466531606950        5.01632193224689      si
       -1.11984429993545       -5.85522416836862        6.98316094869633      h
        4.34039032432114       -6.08728813603224       -0.99552720328946      si
        3.54586288995535       -7.83491305076961       -3.03247750827945      h
        7.05065350984897       -5.75851898025073       -1.63952531530258      h
       -7.30800000000130        2.95500000000301        2.95499999999893      si
       -6.79554888623501        3.92950180502591        5.54800425149037      h
       -6.07813462332742       -1.23341138074673        3.10282156104154      si
       -7.91086668463838       -2.83724388584450        1.70151797682663      h
       -6.31250511695399       -2.26865148844946        5.70303576809164      h
       -5.18517268111156        5.29053405811186       -0.02500121027027      si
       -6.72396524389615        7.34971685203124       -1.10377084539491      h
       -1.53131766023092       -0.85642513545190       -2.24347844704613      si
       -0.61744065906852        1.02256870884859        1.36940112254218      h
        7.66917480872288        1.45919994506266        0.31363248174101      c
        6.65285136510724       -0.33669048060176        0.17797611796493      h
        7.91934196456178        2.69873113210071       -2.86651650520263      s
        9.60036381056200        1.06185323942511        0.91882481173444      h
        0.29218004569995        6.97275018438153        1.06921447512297      c
        0.77533211172229        8.74232737072302        0.12160598152634      h
       -0.00221248703101        5.52606958413067       -0.37065822250511      h
       -2.73290290342971        7.42525988253319        2.56311493762660      s
        4.22630292865646        4.66783284584735        0.98013484231611      c
        4.98377558785302        5.98990335105611       -0.41812866085430      h
        3.06792741719169        3.27291926731373       -0.02851258234432      h
        3.46436306381917        2.71828407871303        6.15979139036808      c
        5.15873483253062        1.45273126316740        4.19322018339138      c
        6.63816094359496        0.36890642739204        5.14749050460011      h
        3.96603385477580        0.11805962664258        3.14593920256420      h
        6.36210795812106        3.20697183014651        2.23826336789439      c
        1.48067538574143        4.34925929896649        4.83119438919284      c
        0.13310084441681        3.09099174097604        3.92431984812975      h
        0.44372162880082        5.44335499721286        6.24666460223491      h
        2.47334942905238        6.11514393230619        2.77743782755989      c
        3.75337710820490        8.41086393793624        3.97035184123234      c
        4.40674419123852        9.70730948471489        2.50500909860944      h
        2.38089774077612        9.42519921107238        5.12751648294856      h
        8.34609047805194        4.99297758860627        3.34733266572909      c
        9.90138489111496        3.89958768491833        4.14575525275979      h
        9.12404498322260        6.14888397706745        1.82571332916493      h
        6.58148487458919        6.99751936403095        5.93244568381226      ge
        8.20092843581630        8.89349640750753        7.36122514913008      h
        1.98954634905449        0.67900933856257        7.65542819962993      c
        0.01261680126182        0.64844349532925        7.07449748772767      h
        3.14080765698384       -2.54361048388239        7.36852123937045      s
        2.05350292651056        1.08336543992601        9.67685656798431      h
        5.03673273902152        4.30538336646664        7.99770271977629      c
        3.82319422292282        5.06166642314857        9.48240342106623      h
        6.45949524473946        3.11661548452282        8.90326383368335      h
$eht charge=0 unpaired=6
$end

"""

// TODO: - Never commit an entire trajectory to GitHub Gist. Always delete the
// text beforehand.
fileprivate let xtbSimulation: String = """

"""

// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MolecularRenderer
import QuaternionModule

struct HydrogenAbstraction {
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
          
          let quaternion = Quaternion<Float>(angle: 0.7, axis: direction)
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
      print(label)
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
    print("atoms:", tooltipDiamondoid.atoms.count + surfaceDiamondoid.atoms.count)
    print("unpaired electrons:", hydrogensToRemove.count)
    provider = ArrayAtomProvider([tooltipDiamondoid, surfaceDiamondoid])
    
    // TODO: Change the anchors. Only the 3 outermost radical atoms should be
    // constrained. This gives the inner atoms more room to adapt to the
    // hydrogens' Pauli repulsion. It results in a very conservative estimate
    // of stiffness. However, now that atoms can actually contribute to the
    // simulation, instead of wasting compute power.
    print(anchors.map { $0 + 1 })
    
    // MARK: - Simulation
    
//    print(exportToXTB(surfaceDiamondoid.atoms))
    //     print(exportToXTB([tooltipDiamondoid, surfaceDiamondoid]))
        #if false
        var minimized = importFromXTB(xtbText)
        minimized = minimized.map {
          var copy = $0
          copy.origin += SIMD3(1, 0, 0)
          return copy
        }
        provider = ArrayAtomProvider(surfaceDiamondoid.atoms + minimized)
        #endif
  }
}

fileprivate let xtbText = """
$coord
        2.98000000000001       -2.15200000000000       -2.15200000000002      si
        8.11100000000004       -7.28299999999994       -2.15199999999991      si
        8.11099999999999       -2.15199999999982       -7.28300000000005      si
       10.35377145969368       -4.11294024156710       -4.11337776018159      si
       11.24813559819791       -2.28008869949299       -2.27993677827648      h
       12.82246680914358       -4.96110468220498       -4.96088488100989      h
       -2.15200000000000        2.97999999999999       -2.15200000000000      si
       -7.28300000000006        8.11099999999995       -2.15200000000024      si
       -2.15199999999983        8.11099999999994       -7.28299999999959      si
       -4.11309608824441       10.35363713490670       -4.11270109328524      si
       -4.95994441282860       12.82279122441483       -4.96017191489364      h
       -2.27944167712681       11.24699150695717       -2.27959887401768      h
        5.34922684155456        5.34937945608331      -10.03764662802719      si
        6.86099797890083        6.86077435877462       -8.32407309870508      h
        8.11099999999978        2.97999999999995      -12.41499999999980      si
        9.87355229739514        5.04298128954095      -12.33565177196745      h
       10.33041462349519        1.03270814964049       -9.21909697749970      si
       12.84209580959330        0.20650693208344       -9.96169916250762      h
       11.13450711349145        2.82575151983170       -7.30481532005889      h
        2.98000000000021        8.11100000000008      -12.41499999999958      si
        5.04326700472809        9.87330062257226      -12.33573402266810      h
        1.03357120650075       10.33016633153923       -9.21749386372056      si
        2.82532834522560       11.13690661595249       -7.30543324465342      h
        0.20640413236465       12.83935371403845       -9.96234767664668      h
        2.98000000000001        2.97999999999995       -7.28299999999997      si
        0.22733002930242        5.35055703384098       -4.90263999414114      si
        1.81124606086336        6.92082270729949       -3.31599492235141      h
        5.35058034971129        0.22746690024087       -4.90278032892479      si
        6.92091880587462        1.81110559020452       -3.31592821644291      h
       -2.15199999999999       -2.15200000000001        2.97999999999998      si
       -7.28299999999990       -2.15200000000014        8.11100000000005      si
       -2.15200000000011       -7.28299999999994        8.11100000000001      si
       -4.11313579313848       -4.11352000661447       10.35383655048162      si
       -2.28038978865931       -2.28021922871597       11.24870442667161      h
       -4.96162083213731       -4.96138535608491       12.82229340035121      h
        5.34947001027410      -10.03765596812405        5.34910623457813      si
        6.86076888632580       -8.32409559683367        6.86098687824233      h
        8.11100000000024      -12.41500000000010        2.98000000000018      si
        9.87322851070819      -12.33585898008609        5.04332894815939      h
       10.32995710452839       -9.21659663176685        1.03450623953020      si
       12.83821901162261       -9.96159296831000        0.20718231473525      h
       11.13710980541523       -7.30527315695550        2.82548693466381      h
        2.97999999999996       -7.28300000000006        2.98000000000040      si
        0.22744062725028       -4.90277010913410        5.35057675394601      si
        1.81108153900363       -3.31590698372143        6.92090130057552      h
        5.35060525144308       -4.90263876834798        0.22729978111590      si
        6.92082229702738       -3.31596209197348        1.81123211596892      h
        2.98000000000120      -12.41499999999952        8.11100000000034      si
        5.04303892777987      -12.33596669290296        9.87339546866552      h
        1.03367719839922       -9.21815455919358       10.33020872304606      si
        0.20748147918012       -9.96080347250929       12.84100999752600      h
        2.82597894099327       -7.30461402152367       11.13451162731410      h
      -10.03765235953809        5.34865784477999        5.34991933421399      si
       -8.32407812339092        6.86095294355421        6.86078676054780      h
       -7.28299999999973        2.97999999999786        2.98000000000163      si
       -4.90267994596781        0.22728799862162        5.35068252981261      si
       -3.31598108642896        1.81123809038711        6.92085992708651      h
       -4.90275073211389        5.35046228508582        0.22748477422198      si
       -3.31593632714434        6.92086861856216        1.81109288462796      h
      -12.41499999999908        8.11100000000190        2.98000000000174      si
      -12.33627578696130        9.87323376883001        5.04303094611650      h
       -9.21813232190815       10.33031489385017        1.03364818359917      si
       -7.30492595506905       11.13539286328123        2.82570616927270      h
       -9.96139010637590       12.84061193049213        0.20699215096136      h
      -12.41499999999357        2.97999999999953        8.11099999999920      si
      -12.33519535856262        5.04326029292649        9.87352703657604      h
       -9.21790797340367        1.03319442996942       10.33012235893189      si
       -9.96204880973608        0.20652256786248       12.84018690653871      h
       -7.30519820091799        2.82547611933390       11.13591718386115      h
        0.24698418619880        0.24702591770618        0.24696208149018      si
        1.82748369784307        1.82749066250870        1.82748217925278      h
$end

"""

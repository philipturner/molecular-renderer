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
          
          let quaternion = Quaternion<Float>(angle: 0.3, axis: direction)
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
        for directionZ in [Float(1), -1] {
          Convex {
            Origin { directionZ * 2 * l }
            Plane { directionZ * l }
          }
        }
        
        Replace { .empty }
      }
    }
    let surfaceAtoms = surfaceLattice.entities.map(MRAtom.init)
//    var surfaceDiamondoid = Diamondoid(atoms: surfaceAtoms)
    
    // Map the surface to silicon and rescale the bonds.
    
    // Record the closest silicon-sulfur bond while placing the tooltip. Record
    // its length and angle from (111) in degrees. Report the C-S-Si angle too.
    // Use trial and error to find the ideal position on the surface. Remove
    // the hydrogen attached to the silicon and remap the bond topology.
    
    provider = ArrayAtomProvider(surfaceAtoms)
//    provider = ArrayAtomProvider([tooltipDiamondoid, surfaceDiamondoid])
    
    // MARK: - Simulation
    
    //     print(exportToXTB([tooltipDiamondoid, surfaceDiamondoid]))
        #if false
        var minimized = importFromXTB(xtbText)
        minimized = minimized.map {
          var copy = $0
          copy.origin += SIMD3(1, 0, 0)
          return copy
        }
        provider = ArrayAtomProvider(tooltipDiamondoid.atoms + minimized)
        #endif
  }
}

fileprivate let xtbText = """
$coord
        3.44399199229851       -3.16747677505113       -3.18936371114192      c
        4.63717066092302       -4.47731244803007       -2.13137965776747      h
        1.35947208582459       -5.05843783419669       -5.08610434484183      s
        4.63341801517251       -2.10276788799378       -4.49654028426620      h
       -3.18933203886304        3.44406029412651       -3.16749499354120      c
       -4.49651328863342        4.63344922958938       -2.10278265189111      h
       -2.13134798538449        4.63727839218242       -4.47727958087681      h
       -5.08603441991406        1.35960531003696       -5.05854940056505      s
        0.44344719108351        0.45510021529654       -2.90159983286753      c
        1.65214951764306        1.67238360612168       -4.05670708031906      h
       -0.70423351799427       -0.69192449040904       -4.18709024064721      h
       -1.34108850448502       -1.35321149652661        2.09921533498816      c
        0.45505376220611       -2.90158179077822        0.44342961300973      c
        1.67232955981442       -4.05670630764915        1.65212307911701      h
       -0.69198177825394       -4.18705448900726       -0.70425920717963      h
        2.09921860605363       -1.34105506176055       -1.35323090871049      c
       -2.90159887155688        0.44347908582615        0.45506673218882      c
       -4.18708960086848       -0.70418641810586       -0.69197122127619      h
       -4.05670426237385        1.65217798396790        1.67235563268492      h
       -1.35321968971417        2.09925889282796       -1.34107321796084      c
        0.07312212123703        4.17272827538892        0.08808076381443      c
        1.08237049537136        5.37844441800916       -1.24369158263211      h
       -1.25990978801982        5.36860450484282        1.10772237098618      h
        4.17270472018807        0.08806903650578        0.07311335175519      c
        5.37841486390125       -1.24372102706945        1.08234597719494      h
        5.36858128209206        1.10771262673607       -1.25991529967192      h
        2.40018566801537        2.40018390187991        2.40019499888236      ge
        4.05463599361086        4.05461174715140        4.05464861132229      h
       -3.16752515875321       -3.18933267844438        3.44398498393523      c
       -4.47734272672973       -2.13133383535775        4.63716420192703      h
       -5.05854494100868       -5.08604523028315        1.35947469213975      s
       -2.10283293355980       -4.49650863939412        4.63341245986778      h
        0.08805894945626        0.07310629303998        4.17270467574895      c
       -1.24371853288885        1.08234305899044        5.37842524166468      h
        1.10769255411005       -1.25994046246293        5.36857049492894      h
$end

"""

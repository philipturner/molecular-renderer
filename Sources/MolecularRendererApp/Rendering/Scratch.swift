// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MolecularRenderer

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
    //   match the different lattice constant and fix any hydrogen bonds.
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
      #if false
      let directions = [
        SIMD3<Float>(1, 1, -1) / Float(3).squareRoot(),
        SIMD3<Float>(1, -1, 1) / Float(3).squareRoot(),
        SIMD3<Float>(-1, 1, 1) / Float(3).squareRoot(),
      ]
      var maximumDistances: [Float] = [0, 0, 0]
      var maximumIndices: [Int] = [0, 0, 0]
      for atomID in tooltipDiamondoid.atoms.indices {
        
      }
      #endif
      
      // Iterate over the indices, fetching the direction corresponding to that
      // index. Use the direction to rotate the bonded atoms. Also, use the
      // vector (-1, -1, -1) to decide which hydrogen becomes sulfur.
      
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
        default: fatalError("Unexpected C and H bonding configuration.")
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
        default: fatalError("Unexpected H, C, and Ge bonding configuration.")
        }
        idealBondLength /= 10
      }
      
      func atomLabel(_ element: UInt8) -> String {
        switch element {
        case 1: return "H"
        case 6: return "C"
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
    
    // print(exportToXTB(tooltipDiamondoid.atoms)
    var minimized = importFromXTB(xtbText)
    minimized = minimized.map {
      var copy = $0
      copy.origin += SIMD3(1, 0, 0)
      return copy
    }
    provider = ArrayAtomProvider(tooltipDiamondoid.atoms + minimized)
    
    // MARK: - Surface
    
      // Create a diamond (111) surface.
//    let surfaceAtoms = Lattice<Cubic> { h, k, l in
//      Bounds { 5 * h + 5 * k + 5 * l }
//      Material { .elemental(.carbon) }
//    }
    
    // Map the surface to silicon and rescale the bonds.
    
    // Record the closest silicon-sulfur bond while placing the tooltip. Record
    // its length and angle from (111) in degrees. Report the C-S-Si angle too.
    // Use trial and error to find the ideal position on the surface.
  }
}

fileprivate let xtbText = """
$coord
        3.42165822128887       -3.17959246844130       -3.17959246844130      c
        4.60877489020857       -4.50400701988634       -2.14689725669305      h
        2.04101363577591       -4.25780353324269       -4.25780353324270      h
        4.60877489020858       -2.14689725669306       -4.50400701988633      h
       -3.17959246844130        3.42165822128887       -3.17959246844130      c
       -4.50400701988633        4.60877489020857       -2.14689725669306      h
       -2.14689725669305        4.60877489020858       -4.50400701988633      h
       -4.25780353324269        2.04101363577591       -4.25780353324270      h
        0.45405432768931        0.45405432768930       -2.89350869480913      c
        1.66768370224544        1.66768370224543       -4.04502272997611      h
       -0.68595008318004       -0.68595008318004       -4.18644998658266      h
       -1.34858534759151       -1.34858534759151        2.11637688927080      c
        0.45405432768930       -2.89350869480912        0.45405432768930      c
        1.66768370224543       -4.04502272997610        1.66768370224543      h
       -0.68595008318004       -4.18644998658266       -0.68595008318004      h
        2.11637688927080       -1.34858534759151       -1.34858534759151      c
       -2.89350869480912        0.45405432768930        0.45405432768930      c
       -4.18644998658266       -0.68595008318004       -0.68595008318005      h
       -4.04502272997611        1.66768370224543        1.66768370224542      h
       -1.34858534759151        2.11637688927080       -1.34858534759151      c
        0.09223608789290        4.17599182493184        0.09223608789289      c
        1.09837921238143        5.37749064896661       -1.24645956241873      h
       -1.24645956241873        5.37749064896660        1.09837921238143      h
        4.17599182493183        0.09223608789289        0.09223608789290      c
        5.37749064896660       -1.24645956241873        1.09837921238143      h
        5.37749064896660        1.09837921238143       -1.24645956241873      h
        2.40248557322277        2.40248557322277        2.40248557322276      ge
        4.06080807101659        4.06080807101658        4.06080807101658      h
       -3.17959246844130       -3.17959246844129        3.42165822128887      c
       -4.50400701988633       -2.14689725669305        4.60877489020858      h
       -4.25780353324270       -4.25780353324270        2.04101363577592      h
       -2.14689725669306       -4.50400701988633        4.60877489020858      h
        0.09223608789289        0.09223608789290        4.17599182493182      c
       -1.24645956241874        1.09837921238144        5.37749064896659      h
        1.09837921238142       -1.24645956241872        5.37749064896660      h
$end

"""

//
//  Chapter12_Figure1.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 10/29/23.
//

import Foundation
import HDL
import MolecularRenderer
import simd

extension Nanosystems.Chapter12 {
  // This figure will be a picture-perfect reproduction of Figure 1. The
  // simulation will be hosted in another stored property. The stacking
  // direction must be vertical to match the MIT thesis.
  struct Figure1/*: Figure3D*/ {
//    var a: Diamondoid
//    var b: Diamondoid
//    var c: Diamondoid
    var provider: any MRAtomProvider
    
    init() {
      provider = ArrayAtomProvider([MRAtom(origin: .zero, element: 6)])
      
      let rodLattice = Lattice<Hexagonal> { h, k, l in
        let h2k = h + 2 * k
        Bounds { 10 * h + 8 * h2k + 20 * l }
        Material { .elemental(.carbon) }
        
        Volume {
          Origin { 5 * h + 4 * h2k + 10 * l }
          
          for direction in [h, -h] {
            Convex {
              Origin { 2 * direction }
              Plane { direction }
            }
          }
          Convex {
            Origin { h2k }
            Plane { h2k }
          }
          for direction in [l, -l] {
            Concave {
              Origin { -h2k }
              Plane { -h2k }
              Convex {
                if direction.z == 1 {
                  Origin { 1.8 * direction }
                } else {
                  Origin { 1 * direction }
                }
                Plane { direction }
              }
            }
          }
          Convex {
            Origin { -4 * h2k }
            Plane { -h2k }
          }
          Replace { .empty }
        }
      }
      let rodAtoms = rodLattice.atoms.map(MRAtom.init)
      var rodDiamondoid = Diamondoid(atoms: rodAtoms)
      provider = ArrayAtomProvider(rodDiamondoid.atoms)
      rodDiamondoid.translate(offset: [
        Float(0.252 * 7.25),
        Float(0.437 * 5.25),
        Float(-0.412 * 2.75)
      ])
      
      // Next, create the housing.
      let housingLattice = Lattice<Hexagonal> { h, k, l in
        let h2k = h + 2 * k
        Bounds { 20 * h + 14 * h2k + 12 * l }
        Material { .elemental(.carbon) }
        
        Volume {
          Origin { 12 * h + 9 * h2k + 6 * l }
          
          // TODO: Always remember to comment your HDL code. Otherwise, it's
          // almost impossible to understand when looking back on it.
          
          // Cut the initial block into an L-shape.
          //
          // There's a compiler bug preventing me from wrapping
          // "Origin { 2.8 * l } - Plane { l }" neatly in a shared scope.
          Concave {
            Origin { 2.8 * l - 2.5 * h2k }
            Plane { l }
            Plane { -h2k }
          }
          
          // Cut a cool chiseled shape around the first rod's housing.
          for direction in [-2 * h - k, h - k] {
            Concave {
              Origin { 2.8 * l }
              if direction.x > 0 {
                Origin { 4.0 * direction }
              } else {
                Origin { 3.5 * direction }
              }
              Plane { l }
              Plane { direction }
            }
          }
          for direction in [h * 2 + k, -h + k] {
            Convex {
              Origin { 5 * direction }
              Plane { direction }
            }
          }
          Concave {
            Origin { 2.8 * l - 6.5 * h }
            Plane { l }
            Plane { -h }
          }
          
          // Chop off a slice of atoms that isn't needed for the second rod.
          Convex {
            Origin { -11 * h }
            Plane { -h }
          }
          
          // Create the hole for the first rod to go through.
          Concave {
            for direction in [h2k, -h2k] {
              Convex {
                if direction.y > 0 {
                  Origin { 3 * direction }
                } else {
                  Origin { 3.5 * direction }
                }
                Plane { -direction }
              }
            }
            for direction in [h, -h] {
              Convex {
                if direction.x > 0 {
                  Origin { 4 * direction }
                } else {
                  Origin { 3.5 * direction }
                }
                Plane { -direction }
              }
            }
            for direction in [h * 2 + k, -h * 2 - k] {
              Convex {
                if direction.y > 0 {
                  if direction.x > 0 {
                    Origin { 3 * direction }
                  }
                } else {
                  Origin { 3 * direction }
                }
                Plane { -direction }
              }
            }
            
            // Create the overhang that stops the first rod from falling out.
            //
            // It seems, the second rod needs to be placed far off-center. The
            // first rod doesn't move far enough for the second rod to run
            // through the middle.
            Volume {
              Concave {
                Origin { -0.5 * h2k }
                Plane { h2k }
                Origin { -2 * h }
                Plane { h + k }
              }
              Replace { .empty }
            }
            Volume {
              Concave {
                for direction in [l, -l] {
                  Convex {
                    if direction[2] > 0 {
                      Origin { 4 * direction }
                    } else {
                      Origin { 4.2 * direction }
                    }
                    Plane { -direction }
                  }
                }
              }
              Replace { .empty }
            }
            
            // Etch a protrusion that theoretically decreases the vdW binding
            // energy of the gate knob. This reduces the force necessary to
            // separate the rod from ~1600 pN to ~1200 pN, much less than
            // expected. The first experiment used 1600 pN in order to finish
            // faster than the break-even force, 1200 pN. Don't confuse that
            // 1600 pN with the ~1600 pN cited here.
            Volume {
              Concave {
                Plane { l }
                Origin { -1.5 * h2k + 4.75 * l }
                Plane { -l }
                Convex {
                  Plane { h2k }
                  for direction in [h, -h] {
                    Convex {
                      Origin { 0.75 * direction }
                      Plane { direction }
                    }
                  }
                }
              }
              Replace { .empty }
            }
          }
        }
        
        secondHole(h, k, l)
      }
      let housingAtoms = housingLattice.atoms.map(MRAtom.init).map {
        var copy = $0
        copy.y -= 0.437
        return copy
      }
      var housingDiamondoid = Diamondoid(atoms: housingAtoms)
      housingDiamondoid.fixHydrogens(tolerance: 0.08) { _ in true }
      housingDiamondoid.minimize()
//      
//      rodDiamondoid.externalForce = [0, 0, -1600]
//      housingDiamondoid.externalForce = [0, 0, 0]
//      
//      housingDiamondoid.anchors = [Bool](
//        repeating: false, count: housingDiamondoid.atoms.count)
//      rodDiamondoid.atomsWithForce = [Bool](
//        repeating: false, count: rodDiamondoid.atoms.count)
//      for index in housingAnchorIndices(housingDiamondoid, ratio: 0.2) {
//        housingDiamondoid.anchors[index] = true
//      }
//      for index in rodForceIndices(rodDiamondoid, direction: [0, 0, 1]) {
//        rodDiamondoid.atomsWithForce[index] = true
//      }
      
      let secondRodLattice = secondRod()
      var secondRodAtoms = secondRodLattice.atoms.map(MRAtom.init)
      secondRodAtoms = secondRodAtoms.map {
        var copy = $0
        copy.x -= 0.252437 * 8
        copy.y -= 0.437 * 0.25
        copy.z -= 0.412228 * 0.25
        return copy
      }
      let secondRodDiamondoid = Diamondoid(atoms: secondRodAtoms)
      
      let allAtoms =
      rodDiamondoid.atoms
      + housingAtoms
//      + housingDiamondoid.atoms
      + secondRodDiamondoid.atoms
      print("Atom count: \(allAtoms.count)")
      provider = ArrayAtomProvider(allAtoms)
      
//      let simulator = MM4(diamondoids: [
//        rodDiamondoid, housingDiamondoid, secondRodDiamondoid
//      ], fsPerFrame: 20)
//      simulator.simulate(ps: 10)
//      provider = simulator.provider
    }
    
    func housingAnchorIndices(_ diamondoid: Diamondoid, ratio: Float) -> [Int] {
      let topY = diamondoid.atoms.reduce(Float.zero) {
        if $1.element == 6 {
          return max($0, $1.origin.y)
        } else {
          return $0
        }
      }
      let bottomY = diamondoid.atoms.reduce(Float.zero) {
        if $1.element == 6 {
          return min($0, $1.origin.y)
        } else {
          return $0
        }
      }
      let topYIndices = diamondoid.atoms.indices.filter {
        let atom = diamondoid.atoms[$0]
        if atom.element == 6, atom.y > topY - 0.2 {
          return true
        } else {
          return false
        }
      }
      let bottomYIndices = diamondoid.atoms.indices.filter {
        let atom = diamondoid.atoms[$0]
        if atom.element == 6, atom.y < bottomY + 0.2 {
          return true
        } else {
          return false
        }
      }
      let combined = Array(topYIndices) + Array(bottomYIndices)
      return combined.filter { _ in
        Float.random(in: 0..<1) < ratio
      }
    }
    
    func rodForceIndices(
      _ diamondoid: Diamondoid, direction: SIMD3<Float>
    ) -> [Int] {
      // Sorted in descending order.
      let sortedIndices = diamondoid.atoms.indices.sorted(by: {
        let atom0 = diamondoid.atoms[$0]
        let atom1 = diamondoid.atoms[$1]
        let dot0 = (atom0.origin * direction).sum()
        let dot1 = (atom1.origin * direction).sum()
        return dot0 > dot1
      })
      var output: [Int] = []
      let numAtoms = diamondoid.atoms.count / 20
      for index in sortedIndices {
        if output.count >= numAtoms {
          break
        }
        if diamondoid.atoms[index].element == 6 {
          output.append(index)
        }
      }
      return output
    }
    
    // We need a better method to measure energy dissipation. This method is
    // often returning negative values for energy entered into the system.
    // Potentially because the PES after the motion has a lower minimum than
    // before. Maybe, find the energy to return the rod to its original
    // position.
    //
    // First attempt to measure energy loss: ~30-70 zJ per half cycle, where the
    // rod's intermediate velocity is 100 m/s. Didn't measure how much kinetic
    // energy was lost along the trajectory due to friction (seemed on the
    // order of 10 zJ). The priority right now is recovering potential energy
    // and properly handling the unevenness of the potential energy surface.
    // And, getting more stable energy measurements in OpenMM. Perhaps run
    // these calculations at 2 fs/step or 1 fs/step for precise energy
    // measurements. Also, fix the integrator's kinetic energy expression to
    // measure thermal energy - organized kinetic energy.
    //
    // Get this right when reproducing figure 2. For now, just focus on
    // getting figure 1 to work at all, with the energy recovery mechanism in
    // place. Just don't cite any energy measurements, as they're faulty. You
    // can report a set of graphs: x / t, v / t, force / x, force / t.
    //
    /*
     WARNING: The absolute energy (fifth column) is not accurate. Kinetic
     energy is also misleading, as this experiment doesn't report the thermal
     energy. Bulk organized kinetic energy will obviously slow to 0, because of
     the second law of thermodynamics. What it does provide, is a good set of
     keyframes for a force-distance curve to create smooth motion.
     0.2 ps   0.002 nm   1600 pN   6 m/s   2 zJ   2 zJ kinetic   0 zJ other
     0.4 ps   0.008 nm   1600 pN   18 m/s   8 zJ   16 zJ kinetic   -9 zJ other
     0.6 ps   0.017 nm   1600 pN   28 m/s   17 zJ   39 zJ kinetic   -23 zJ other
     0.8 ps   0.029 nm   1600 pN   36 m/s   28 zJ   63 zJ kinetic   -35 zJ other
     1.0 ps   0.041 nm   1600 pN   41 m/s   41 zJ   73 zJ kinetic   -32 zJ other
     1.2 ps   0.053 nm   1600 pN   43 m/s   55 zJ   60 zJ kinetic   -5 zJ other
     1.4 ps   0.062 nm   1600 pN   43 m/s   69 zJ   46 zJ kinetic   23 zJ other
     1.6 ps   0.069 nm   1600 pN   40 m/s   82 zJ   35 zJ kinetic   47 zJ other
     1.8 ps   0.073 nm   1600 pN   37 m/s   94 zJ   31 zJ kinetic   62 zJ other
     2.0 ps   0.077 nm   1600 pN   36 m/s   105 zJ   34 zJ kinetic   72 zJ other
     2.2 ps   0.082 nm   1600 pN   38 m/s   117 zJ   36 zJ kinetic   81 zJ other
     2.4 ps   0.087 nm   1600 pN   39 m/s   130 zJ   38 zJ kinetic   92 zJ other
     2.6 ps   0.094 nm   1600 pN   41 m/s   143 zJ   48 zJ kinetic   95 zJ other
     2.8 ps   0.103 nm   1600 pN   45 m/s   158 zJ   55 zJ kinetic   102 zJ other
     3.0 ps   0.114 nm   1600 pN   52 m/s   174 zJ   60 zJ kinetic   114 zJ other
     3.2 ps   0.127 nm   1600 pN   61 m/s   194 zJ   80 zJ kinetic   114 zJ other
     3.4 ps   0.142 nm   1600 pN   72 m/s   217 zJ   119 zJ kinetic   98 zJ other
     3.6 ps   0.161 nm   1600 pN   87 m/s   244 zJ   168 zJ kinetic   76 zJ other
     3.8 ps   0.183 nm   1600 pN   103 m/s   277 zJ   224 zJ kinetic   54 zJ other
     4.0 ps   0.207 nm   1600 pN   120 m/s   316 zJ   286 zJ kinetic   30 zJ other
     4.2 ps   0.233 nm   0 pN   129 m/s   316 zJ   312 zJ kinetic   4 zJ other
     4.4 ps   0.257 nm   0 pN   124 m/s   316 zJ   281 zJ kinetic   35 zJ other
     4.6 ps   0.277 nm   0 pN   111 m/s   316 zJ   241 zJ kinetic   75 zJ other
     4.8 ps   0.295 nm   0 pN   99 m/s   316 zJ   237 zJ kinetic   79 zJ other
     5.0 ps   0.311 nm   0 pN   93 m/s   316 zJ   254 zJ kinetic   61 zJ other
     5.2 ps   0.328 nm   0 pN   92 m/s   316 zJ   255 zJ kinetic   61 zJ other
     5.4 ps   0.346 nm   0 pN   94 m/s   316 zJ   242 zJ kinetic   74 zJ other
     5.6 ps   0.366 nm   0 pN   100 m/s   316 zJ   232 zJ kinetic   84 zJ other
     5.8 ps   0.387 nm   0 pN   107 m/s   316 zJ   227 zJ kinetic   89 zJ other
     6.0 ps   0.410 nm   0 pN   112 m/s   316 zJ   231 zJ kinetic   85 zJ other
     6.2 ps   0.432 nm   0 pN   113 m/s   316 zJ   242 zJ kinetic   74 zJ other
     6.4 ps   0.455 nm   0 pN   112 m/s   316 zJ   250 zJ kinetic   66 zJ other
     6.6 ps   0.476 nm   0 pN   107 m/s   316 zJ   251 zJ kinetic   65 zJ other
     6.8 ps   0.497 nm   0 pN   101 m/s   316 zJ   234 zJ kinetic   82 zJ other
     7.0 ps   0.516 nm   0 pN   96 m/s   316 zJ   209 zJ kinetic   107 zJ other
     7.2 ps   0.536 nm   0 pN   96 m/s   316 zJ   187 zJ kinetic   129 zJ other
     7.4 ps   0.556 nm   0 pN   101 m/s   316 zJ   186 zJ kinetic   130 zJ other
     7.6 ps   0.578 nm   0 pN   110 m/s   316 zJ   222 zJ kinetic   94 zJ other
     7.8 ps   0.601 nm   0 pN   118 m/s   316 zJ   263 zJ kinetic   53 zJ other
     8.0 ps   0.625 nm   0 pN   123 m/s   316 zJ   289 zJ kinetic   27 zJ other
     8.2 ps   0.650 nm   0 pN   122 m/s   316 zJ   283 zJ kinetic   33 zJ other
     8.4 ps   0.673 nm   0 pN   117 m/s   316 zJ   255 zJ kinetic   61 zJ other
     8.6 ps   0.695 nm   0 pN   110 m/s   316 zJ   226 zJ kinetic   90 zJ other
     8.8 ps   0.716 nm   0 pN   104 m/s   316 zJ   204 zJ kinetic   112 zJ other
     9.0 ps   0.736 nm   0 pN   102 m/s   316 zJ   201 zJ kinetic   114 zJ other
     9.2 ps   0.757 nm   0 pN   102 m/s   316 zJ   232 zJ kinetic   84 zJ other
     9.4 ps   0.779 nm   0 pN   107 m/s   316 zJ   275 zJ kinetic   40 zJ other
     9.6 ps   0.802 nm   0 pN   114 m/s   316 zJ   305 zJ kinetic   11 zJ other
     9.8 ps   0.827 nm   0 pN   120 m/s   316 zJ   324 zJ kinetic   -8 zJ other
     10.0 ps   0.852 nm   0 pN   122 m/s   316 zJ   324 zJ kinetic   -9 zJ other
     10.2 ps   0.877 nm   0 pN   118 m/s   316 zJ   280 zJ kinetic   36 zJ other
     10.4 ps   0.898 nm   0 pN   106 m/s   316 zJ   206 zJ kinetic   110 zJ other
     10.6 ps   0.916 nm   0 pN   93 m/s   316 zJ   173 zJ kinetic   143 zJ other
     10.8 ps   0.932 nm   0 pN   85 m/s   316 zJ   191 zJ kinetic   125 zJ other
     11.0 ps   0.948 nm   0 pN   83 m/s   316 zJ   224 zJ kinetic   91 zJ other
     11.2 ps   0.964 nm   0 pN   86 m/s   316 zJ   228 zJ kinetic   88 zJ other
     11.4 ps   0.982 nm   0 pN   92 m/s   316 zJ   210 zJ kinetic   105 zJ other
     11.6 ps   1.001 nm   0 pN   98 m/s   316 zJ   201 zJ kinetic   114 zJ other
     11.8 ps   1.022 nm   0 pN   104 m/s   316 zJ   206 zJ kinetic   110 zJ other
     12.0 ps   1.043 nm   0 pN   107 m/s   316 zJ   213 zJ kinetic   103 zJ other
     12.2 ps   1.065 nm   0 pN   106 m/s   316 zJ   212 zJ kinetic   104 zJ other
     12.4 ps   1.085 nm   0 pN   101 m/s   316 zJ   204 zJ kinetic   112 zJ other
     12.6 ps   1.104 nm   0 pN   95 m/s   316 zJ   190 zJ kinetic   126 zJ other
     12.8 ps   1.122 nm   0 pN   88 m/s   316 zJ   160 zJ kinetic   156 zJ other
     13.0 ps   1.138 nm   0 pN   82 m/s   316 zJ   127 zJ kinetic   189 zJ other
     13.2 ps   1.154 nm   0 pN   81 m/s   316 zJ   121 zJ kinetic   194 zJ other
     13.4 ps   1.171 nm   0 pN   85 m/s   316 zJ   153 zJ kinetic   162 zJ other
     13.6 ps   1.189 nm   0 pN   93 m/s   316 zJ   201 zJ kinetic   115 zJ other
     13.8 ps   1.210 nm   0 pN   102 m/s   316 zJ   244 zJ kinetic   71 zJ other
     14.0 ps   1.231 nm   0 pN   109 m/s   316 zJ   263 zJ kinetic   53 zJ other
     14.2 ps   1.254 nm   0 pN   112 m/s   316 zJ   269 zJ kinetic   47 zJ other
     14.4 ps   1.275 nm   -1600 pN   108 m/s   281 zJ   242 zJ kinetic   39 zJ other
     14.6 ps   1.295 nm   -1600 pN   98 m/s   250 zJ   187 zJ kinetic   63 zJ other
     14.8 ps   1.312 nm   -1600 pN   86 m/s   222 zJ   143 zJ kinetic   79 zJ other
     15.0 ps   1.327 nm   -1600 pN   75 m/s   198 zJ   122 zJ kinetic   76 zJ other
     15.2 ps   1.341 nm   -1600 pN   69 m/s   176 zJ   120 zJ kinetic   56 zJ other
     15.4 ps   1.354 nm   -1600 pN   67 m/s   155 zJ   114 zJ kinetic   41 zJ other
     15.6 ps   1.368 nm   -1600 pN   68 m/s   133 zJ   113 zJ kinetic   20 zJ other
     15.8 ps   1.382 nm   -1600 pN   69 m/s   111 zJ   116 zJ kinetic   -5 zJ other
     16.0 ps   1.396 nm   -1600 pN   71 m/s   88 zJ   116 zJ kinetic   -28 zJ other
     16.2 ps   1.411 nm   -1600 pN   71 m/s   65 zJ   106 zJ kinetic   -41 zJ other
     16.4 ps   1.424 nm   -1600 pN   65 m/s   44 zJ   80 zJ kinetic   -35 zJ other
     16.6 ps   1.435 nm   -1600 pN   58 m/s   26 zJ   64 zJ kinetic   -38 zJ other
     16.8 ps   1.445 nm   -1600 pN   51 m/s   9 zJ   54 zJ kinetic   -45 zJ other
     17.0 ps   1.453 nm   -1600 pN   39 m/s   -3 zJ   39 zJ kinetic   -42 zJ other
     17.2 ps   1.459 nm   -1600 pN   28 m/s   -12 zJ   23 zJ kinetic   -35 zJ other
     17.4 ps   1.463 nm   -1600 pN   20 m/s   -19 zJ   11 zJ kinetic   -30 zJ other
     17.6 ps   1.464 nm   -1600 pN   9 m/s   -21 zJ   5 zJ kinetic   -26 zJ other
     17.8 ps   1.463 nm   -1600 pN   -10 m/s   -18 zJ   5 zJ kinetic   -23 zJ other
     18.0 ps   1.457 nm   0 pN   -28 m/s   -18 zJ   19 zJ kinetic   -38 zJ other
     18.2 ps   1.450 nm   0 pN   -34 m/s   -18 zJ   32 zJ kinetic   -51 zJ other
     18.4 ps   1.443 nm   0 pN   -36 m/s   -18 zJ   47 zJ kinetic   -65 zJ other
     18.6 ps   1.436 nm   0 pN   -38 m/s   -18 zJ   69 zJ kinetic   -88 zJ other
     18.8 ps   1.428 nm   0 pN   -40 m/s   -18 zJ   80 zJ kinetic   -99 zJ other
     19.0 ps   1.421 nm   0 pN   -38 m/s   -18 zJ   68 zJ kinetic   -86 zJ other
     19.2 ps   1.415 nm   0 pN   -30 m/s   -18 zJ   42 zJ kinetic   -60 zJ other
     19.4 ps   1.412 nm   0 pN   -16 m/s   -18 zJ   13 zJ kinetic   -31 zJ other
     19.6 ps   1.412 nm   0 pN   -1 m/s   -18 zJ   2 zJ kinetic   -21 zJ other
     19.8 ps   1.414 nm   0 pN   13 m/s   -18 zJ   33 zJ kinetic   -52 zJ other
     20.0 ps   1.418 nm   0 pN   22 m/s   -18 zJ   79 zJ kinetic   -98 zJ other
     20.2 ps   1.424 nm   0 pN   28 m/s   -18 zJ   94 zJ kinetic   -112 zJ other
     20.4 ps   1.429 nm   0 pN   30 m/s   -18 zJ   77 zJ kinetic   -95 zJ other
     20.6 ps   1.434 nm   0 pN   26 m/s   -18 zJ   47 zJ kinetic   -65 zJ other
     20.8 ps   1.439 nm   0 pN   25 m/s   -18 zJ   27 zJ kinetic   -45 zJ other
     21.0 ps   1.444 nm   0 pN   23 m/s   -18 zJ   16 zJ kinetic   -34 zJ other
     21.2 ps   1.449 nm   0 pN   23 m/s   -18 zJ   14 zJ kinetic   -33 zJ other
     21.4 ps   1.453 nm   0 pN   22 m/s   -18 zJ   25 zJ kinetic   -43 zJ other
     21.6 ps   1.458 nm   0 pN   22 m/s   -18 zJ   44 zJ kinetic   -62 zJ other
     */
    func energyMeasurementFailure() {
      // This experiment was done when only 1 rod and the housing were written.
      // The second rod was added later.
      #if false
      let pos1 = rodDiamondoid.createCenterOfMass()
      
      // Force in pN.
      var currentForce: Float = 1600
      var previousPos: SIMD3<Float>?
      var energy: Float = 0
      let deltaT: Double = 0.2
      var stopForce: Bool = false
      var stopForceTime: Int = 0
      
      for picosecond in 1...150 {
        rodDiamondoid.externalForce = [0, 0, -currentForce]
        let externalForces = rodDiamondoid.createForces() + housingDiamondoid.createForces()
        simulator.changeExternalForces(externalForces)
        simulator.simulate(
          ps: deltaT, minimizing: true, silent: true)
        
        rodDiamondoid.atoms = simulator
          .newIndicesMap[0..<rodDiamondoid.atoms.count].map {
          simulator.provider.states.last![Int($0)]
        }
        let pos2 = rodDiamondoid.createCenterOfMass()
        let x = simd_distance(pos1, pos2)
        var deltaX: Float
        var positionChange: SIMD3<Float>
        if let previousPos {
          positionChange = pos2 - previousPos
          deltaX = simd_distance(pos2, previousPos)
        } else {
          positionChange = pos2 - pos1
          deltaX = simd_distance(pos2, pos1)
        }
        energy += simd_dot(positionChange, [0, 0, -currentForce])
        previousPos = pos2
        
        func fmt(_ number: Float) -> String {
          String(format: "%.3f", number)
        }
        func fmts(_ number: Double) -> String {
          String(format: "%.1f", number)
        }
        func fmte(_ number: Float) -> String {
          String(Int(number.rounded(.toNearestOrEven)))
        }
        
        let velocity = 1000 * (deltaX / Float(deltaT))
        let mass = rodDiamondoid.createMass() / 1000 / 6.022e23
        let kinetic = 0.5 * mass * velocity * velocity / 1e-21
        
        print(
          "\(fmts(Double(picosecond) * deltaT)) ps\t",
          "\(fmt(x)) nm\t",
          "\(fmte(currentForce)) pN\t",
          "\(fmte(1000 * -positionChange.z / Float(deltaT))) m/s\t",
          "\(fmte(energy)) zJ\t",
          "\(fmte(kinetic)) zJ kinetic\t",
          "\(fmte(energy - kinetic)) zJ other\t")
        
        if x > 0.8, positionChange.z > 0, stopForceTime == 0 {
          stopForce = true
          stopForceTime = picosecond
        }
        if x > 1.45 - 0.2 {
          currentForce = -1600
        } else if x > 0.2 {
          currentForce = 0
        } else {
          currentForce = 1600
        }
        if stopForce {
//          currentForce = 200
//          if picosecond - stopForceTime > Int(5 / deltaT) {
            currentForce = 0
//          }
        }
      }
      #endif
    }
  }
}

//
//  Bootstrapping_Surface.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/10/23.
//

import HDL
import MolecularRenderer
import Numerics

// The surface needs to be improved, so that it's more realistic.
//
// 1) Fix up the code for initializing the 160-cell gold surface, so it doesn't
//    take 1.6 seconds. ✅
//    -> make changes to the compiler instead of changing the code here
//    -> skip cells that aren't intersected by the plane, only for cubic
//      -> hexagonal doesn't need the optimization because its coordinate system
//         is already oriented with 3-fold symmetry on a cartesian axis
//    -> maybe parallelize over multicore CPU
// 2) Make the gold surface maximally thin so you can fit more surface area
//    with the same rendering cost. ✅
// 3) Achieve this by emulating a few randomly spaced ledges (within a certain
//    margin of safety from the central build plate). This makes it a bit harder
//    to plan trajectories and better represents real-world conditions. ✅
// 4) Finish up the code that makes a bounding box for each ledge.
//
// Finish the rest of this scene another time; each component of the project
// can be worked on in bits.

extension Bootstrapping {
  struct Surface {
    var atoms: [MRAtom] = []
    var ledges: SurfaceLedges
    
    // These are not the center of mass, max Y, etc. of the actual object. Only
    // parameters used while transforming points. Therefore, they are private.
    private var centerOfMass: SIMD3<Float>
    private var basis: (x: SIMD3<Float>, y: SIMD3<Float>, z: SIMD3<Float>)
    private var maxY: Float = .nan
    
    init() {
      // Create the ledges before the lattice is compiled. Access the ledges
      // during the compilation, then transform them afterward.
      self.ledges = SurfaceLedges()
      
      // Create a hexagon of gold. Make it truly gigantic.
      let scaleFactor: Float = 6
      let lattice = Lattice<Cubic> { [ledges] h, k, l in
        Bounds { scaleFactor * 40 * (h + k + l) }
        Material { .elemental(.gold) }
        
        Volume {
          Convex {
            Origin { scaleFactor * 20 * (h + k + l) }
            Origin { 0.5 * (h + k + l) }
            
            Convex {
              Origin { 3 * (h + k + l) }
              Plane { h + k + l }
            }
            Convex {
              Origin { -3 * (h + k + l) }
              Plane { -(h + k + l) }
            }
            
            // Set the effective center of the line to 0.375 unit cells
            // off in the alignment direction.
            //
            // Test the data structure for describing the ledges by placing some
            // oxygen atoms dotted along each ledge's bounds. Ensure the
            // bounding box looks correct, otherwise adjust it.
            
            // Make the spacings in nm by dividing by the lattice constant.
            let latticeConstant = Constant(.square) { .elemental(.gold) }
            let cutOffset = ledges.cutOffset / latticeConstant
            let cutSpacing = ledges.cutSpacing / latticeConstant
            
            for integer in -11...11 {
              if (integer & 1) == 0 {
                // Skip even integers.
                continue
              }
              Convex {
                // Set the offset of this ledge in particular.
                Origin {
                  Float(integer) / 2 * cutSpacing * ledges.cutAlignment
                }
                Origin {
                  Float(integer - 1) / 3 * (h + k + l)
                }
                
                // Make 2 cuts in the crystal.
                Concave {
                  // Points up and sideways.
                  Origin {
                    cutOffset * ledges.cutAlignment
                  }
                  Plane { ledges.cutNormal }
                  
                  // Points straight up.
                  Origin {
                    0 * (h + k + l)
                  }
                  Plane { h + k + l }
                }
                Concave {
                  // Points down and sideways.
                  Origin {
                    (0.75 + cutOffset) * ledges.cutAlignment
                  }
                  Plane { -ledges.cutNormal }
                  
                  // Points straight down.
                  Origin {
                    0.25 * (h + k + l)
                  }
                  Plane { -(h + k + l) }
                }
              }
            }
          }
          
          Replace { .empty }
        }
      }
      
      // Create a list of atoms that is transformed.
      var goldAtoms = lattice.atoms
      print("gold atoms:", goldAtoms.count)
      
      // Read the center of mass when there are no ledges, then use that
      // number for geometries with ledges. Repeat this every time the surface
      // size changes.
      do {
        var centerOfMass: SIMD3<Double> = .zero
        for entity in goldAtoms {
          centerOfMass += SIMD3(entity.position)
        }
        centerOfMass /= Double(goldAtoms.count)
        //        print(centerOfMass)
        centerOfMass = SIMD3(49.00396455334486, 49.00396455334486, 49.00396455334486)
        self.centerOfMass = SIMD3(centerOfMass)
      }
      
      // Center the surface at the world origin.
      for i in goldAtoms.indices {
        goldAtoms[i].position -= self.centerOfMass
      }
      
      // Rotate the hexagon so its normal points toward +Y.
      let axis1 = cross_platform_normalize([1, 0, -1])
      let axis3 = cross_platform_normalize([1, 1, 1])
      let axis2 = cross_platform_cross(axis1, axis3)
      self.basis = (SIMD3(axis1), SIMD3(axis3), SIMD3(axis2))
      for i in goldAtoms.indices {
        goldAtoms[i].position = transform(direction: goldAtoms[i].position)
      }
      
      // As with the center of mass, use a value from when the surface has no
      // elevation (actually, 0.5 unit cells of elevation in (111)).
      do {
        var maxY: Float = -.greatestFiniteMagnitude
        for atom in goldAtoms {
          maxY = max(maxY, atom.position.y)
        }
        //        print(maxY)
        maxY = 0.117731094
        self.maxY = maxY
      }
      
      // Shift the atoms, so that Y=0 coincides with the highest atom.
      for i in goldAtoms.indices {
        goldAtoms[i].position.y -= self.maxY
      }
      
      // Set the object's atoms to the final version of the gold atoms.
      // [TODO] Append some oxygen atoms while debugging ledges.
      self.atoms = goldAtoms.map(MRAtom.init)
    }
    
    // Functions to transform the contents from the lattice basis to the new
    // one. This could be used to reposition the atoms and ledges.
    
    @inline(__always)
    func transform(position: SIMD3<Float>) -> SIMD3<Float> {
      // Only used for ledges, as some parameters require knowledge of the
      // atoms' final positions to initialize.
      var output = position - centerOfMass
      output = transform(direction: output)
      output.y -= maxY
      return output
    }
    
    @inline(__always)
    func transform(direction: SIMD3<Float>) -> SIMD3<Float> {
      // Used for atoms and ledges.
      let componentH = (direction * SIMD3(basis.x)).sum()
      let componentL = (direction * SIMD3(basis.y)).sum()
      let componentH2K = (direction * SIMD3(basis.z)).sum()
      return SIMD3(componentH, componentL, componentH2K)
    }
  }
}

extension Bootstrapping {
  struct SurfaceLedges {
    var cutAlignment: SIMD3<Float>
    var cutNormal: SIMD3<Float>
    var cutOffset: Float
    var cutSpacing: Float
    
    init() {
      let revolutions = Float.random(in: 0..<1)
      let axis = cross_platform_normalize(SIMD3<Float>(1, 1, 1))
      let rotation = Quaternion<Float>(
        angle: revolutions * 2 * .pi, axis: axis)
      
      self.cutAlignment = cross_platform_normalize(SIMD3<Float>(1, 0, -1))
      self.cutAlignment = rotation.act(on: cutAlignment)
      
      self.cutNormal = cross_platform_normalize(-cutAlignment + axis)
      self.cutOffset = Float.random(in: -1..<1)
      self.cutSpacing = Float.random(in: 18..<20)
    }
    
    // Function to mutate the ledges, mapping them from the cubic lattice basis
    // to the new one. As the ledge's properties might change independently of
    // the surface, it's best to encapsulate the code somewhere besides
    // 'Surface.init'.
    
    // Function that gives you a conservative estimate of elevation based on an
    // entered position. This could be used to place tripods or generate
    // camera keyframes.
    
    // Function that tells you whether you're directly on top of a ledge. This
    // could be used to avoid placing tripods on ledges.
    
    // Function that creates a bounding box representation of the ledges, for
    // debugging. The atoms are oxygen because the red color is easy to spot.
  }
}

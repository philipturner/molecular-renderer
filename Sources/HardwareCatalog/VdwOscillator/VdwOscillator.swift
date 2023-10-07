//
//  VdwOscillator.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/28/23.
//

import HDL

internal func vdwOscillator() {
  // Make a housing, where a solid diamond slab can fit inside it.
  var housing = Lattice<Cubic> { h, k, l in
    let width: Float = 18
    let thickness: Float = 3
    Material { .carbon }
    Bounds { width * h + width * k + width * l }
    
    Volume {
      Origin { width / 2 * l }
      Ridge(l) { -k }
      
      Origin { width * k }
      Ridge(l) { +k }
      Cut()
    }
    Volume {
      Origin { width * k + width * l }
      Plane { -k + l }
      Cut()
    }
    Volume {
      Origin { width / 2 * k + width / 2 * l }
      Plane { -k - l }
      Cut()
    }
    
    // Add some circular supports on the corners for improved stiffness.
    Convex {
      Origin { width * k + width / 2 * l }
      Volume {
        Concave {
          Origin { -0.5 * k }
          Ridge(l) { +k }
          
          Origin { -2 * k } // -2.5
          Plane { +k }
        }
        Cut()
      }
      Volume {
        Concave {
          Origin { -1 * k }
          Ridge(l) { +k }
          
          Origin { -0.75 * k } // -1.75
          Plane { +k }
        }
        Cut()
      }
      Volume {
        Concave {
          Convex {
            Origin { -thickness * k }
            Valley(l) { -k }
          }
          
          Origin { -3.75 * k }
          Plane { -k }
          
          Origin { -1 * k }
          Ridge(l) { -k }
        }
        Cut()
      }
    }
    Volume {
      Origin { 20 * h + width * k + width / 2 * l }
      Concave {
        Convex {
          Origin { -0.5 * h - thickness * k }
          Plane { h + k - l }
        }

        Convex {
          Origin { -0.5 * h }
          Plane { h - k + l }
        }
        Convex {
          Plane { h - k - l }
        }
        Convex {
          Origin { -1 * h - thickness * k }
          Plane { h + k + l }
        }
      }
      Cut()
    }
    
    let holeX: Float = 6
    Volume {
      Concave {
        Convex {
          Origin { holeX * h }
          Plane { -h }
        }
        Origin { width * k + width / 2 * l }
        Convex {
          Origin { -2.5 * k + -2 * l }
          Plane { -k - l }
        }
        Convex {
          Origin { -3.75 * k + -1.75 * l }
          Plane { k - l }
        }
        Convex {
          Origin { holeX * h }
          Origin { -4 * k + -1.5 * l }
          Plane { -h - k - l }
        }
      }
      Cut()
    }
    Volume {
      Concave {
        Convex {
          Origin { (holeX + 2) * h }
          Plane { -h }
        }
        Origin { width * k + width / 2 * l }
        Origin { -4 * k + -1.5 * l }
        Convex {
          Origin { -4 * k + -1.5 * l }
          Plane { -k - l }
        }
        Origin { holeX * h }
        Convex {
          Plane { -h - k - l }
        }
        Convex {
          Origin { 1 * h + 1 * k }
          Ridge(-k + l) { -h }
        }
      }
      Cut()
    }
    Volume {
      Concave {
        Convex {
          Origin { 2.75 * h }
          Plane { -h }
        }
        Origin { width * k + width / 2 * l }
        Origin { -4 * k + -1.5 * l }
        Convex {
          Plane { -k + l }
        }
        Convex {
          Origin { 0.5 * h }
          Plane { -h - k + l }
        }
        Convex {
          Origin { 2 * h + 1 * k }
          Ridge(k + l) { -h }
        }
      }
      Cut()
    }
    
    // Remove a lone atom that's sticking out with 3 dangling bonds.
    Volume {
      Concave {
        Convex {
          Origin { (width / 2 + 2) * l }
          Plane { +l }
        }
        Convex {
          Origin { 0.25 * h }
          Plane { -h }
        }
      }
      Cut()
    }
  }
  
  do {
    let width: Float = 18
    housing = Lattice<Cubic> { h, k, l in
      Copy { housing }
      Affine {
        Copy { housing }
        Reflect { k }
        Origin { width / 2 * l }
        Rotate { 0.25 * h }
      }
    }
    housing = Lattice<Cubic> { h, k, l in
      Copy { housing }
      Affine {
        Copy { housing }
        Origin { width / 2 * l }
        Rotate { 0.5 * h }
      }
    }
    housing = Lattice<Cubic> { h, k, l in
      Copy { housing }
      Affine {
        Copy { housing }
        Reflect { h }
        Reflect { l }
      }
    }
  }
  
  // Make a diamond slab that is superlubricant.
  var rod = Lattice<Cubic> { h, k, l in
    let width: Float = 14
    let thickness: Float = 6
    Material { .carbon }
    Bounds { width * h + width * k + width * l }
    
    Volume {
      Origin { width / 2 * h + width / 2 * k }
      Convex {
        Origin { -1.5 * k }
        Plane { h - k }
      }
      Convex {
        Origin { 1.5 * k }
        Plane { -h + k }
      }
      Cut()
    }
    Volume {
      Origin { width * h + width * k }
      Convex {
        Origin { -1 * h }
        Plane { h + k }
      }
      Convex {
        Origin { -1 * h + (thickness - 1.5) * l }
        Plane { -h + k + l }
      }
      Convex {
        Origin { -1 * h + 0.5 * l }
        Plane { -h + k - l }
      }
      Convex {
        Origin { -1 * k + (thickness - 1.5) * l }
        Plane { h - k + l }
      }
      Convex {
        Origin { -1 * k + 0.5 * l }
        Plane { h - k - l }
      }
      Convex {
        Origin { (thickness - 2.5) * l }
        Plane { h + k + l }
      }
      Convex {
        Origin { 1.5 * l }
        Plane { h + k - l }
      }
      Cut()
    }
  }
  
  rod = Lattice<Cubic> { h, k, l in
    Affine {
      Copy { rod }
      Translate { -4 * h + -4 * k }
    }
    Affine {
      Copy { rod }
      Reflect { h }
      Rotate { 0.25 * l }
    }
  }
  rod = Lattice<Cubic> { h, k, l in
    Copy { rod }
    Affine {
      Copy { rod }
      Translate { -1 * l }
    }
  }
  rod = Lattice<Cubic> { h, k, l in
    for i in 0..<3 {
      Affine {
        Copy { rod }
        Translate { Float(i) * h + Float(-i) * k }
      }
    }
    Volume {
      let thickness: Float = 6
      Convex {
        Origin { (thickness - 0.25) * l }
        Plane { +l }
      }
      Convex {
        Origin { -(thickness - 0.25) * l }
        Plane { -l }
      }
      Replace { .single }
    }
  }
  
  // Last steps: casting to Solid and making the assembly
}

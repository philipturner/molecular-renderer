//
//  VdwOscillator.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/28/23.
//

import Shapes
import HDL

// This should be kept in the assemblies folder because a lot of parameters
// are hard-coded.

public struct VdwOscillator {
  public init() {
    
  }
}

func vdwOscillator() {
  // Make a housing, where a solid diamond slab can fit inside it.

  var housing = Lattice<Cubic> {
    let width: Float = 18
    let thickness: Float = 3
    Material { .carbon }
    Bounds { width * x + width * y + width * z }
    
    Volume {
      Origin { width / 2 * z }
      Ridge(z) { -y }
      
      Origin { width * y }
      Ridge(z) { +y }
      Cut()
    }
    Volume {
      Origin { width * y + width * z }
      Plane { -y ^ +z }
      Cut()
    }
    Volume {
      Origin { width / 2 * y + width / 2 * z }
      Plane { -y ^ -z }
      Cut()
    }
    
    // Add some circular supports on the corners for improved stiffness.
    Convex {
      Origin { width * y + width / 2 * z }
      Volume {
        Concave {
          Origin { -0.5 * y }
          Ridge(z) { +y }
          
          Origin { -2 * y } // -2.5
          Plane { +y }
        }
        Cut()
      }
      Volume {
        Concave {
          Origin { -1 * y }
          Ridge(z) { +y }
          
          Origin { -0.75 * y } // -1.75
          Plane { +y }
        }
        Cut()
      }
      Volume {
        Concave {
          Convex {
            Origin { -thickness * y }
            Valley(z) { -y }
          }
          
          Origin { -3.75 * y }
          Plane { -y }
          
          Origin { -1 * y }
          Ridge(z) { -y }
        }
        Cut()
      }
    }
    Volume {
      Origin { 20 * x + width * y + width / 2 * z }
      Concave {
        Convex {
          Origin { -0.5 * x - thickness * y }
          Plane { +x ^ +y ^ -z }
        }
        Convex {
          Origin { -0.5 * x }
          Plane { +x ^ -y ^ +z }
        }
        Convex {
          Plane { +x ^ -y ^ -z }
        }
        Convex {
          Origin { -1 * x - thickness * y }
          Plane { +x ^ +y ^ +z }
        }
      }
      Cut()
    }
    
    let holeX: Float = 6
    Volume {
      Concave {
        Convex {
          Origin { holeX * x }
          Plane { -x }
        }
        Origin { width * y + width / 2 * z }
        Convex {
          Origin { -2.5 * y + -2 * z }
          Plane { -y ^ -z }
        }
        Convex {
          Origin { -3.75 * y + -1.75 * z }
          Plane { +y ^ -z }
        }
        Convex {
          Origin { holeX * x }
          Origin { -4 * y + -1.5 * z }
          Plane { -x ^ -y ^ -z }
        }
      }
      Cut()
    }
    Volume {
      Concave {
        Convex {
          Origin { (holeX + 2) * x }
          Plane { -x }
        }
        Origin { width * y + width / 2 * z }
        Origin { -4 * y + -1.5 * z }
        Convex {
          Origin { -4 * y + -1.5 * z }
          Plane { -y ^ -z }
        }
        Origin { holeX * x }
        Convex {
          Plane { -x ^ -y ^ -z }
        }
        Convex {
          Origin { 1 * x + 1 * y }
          Ridge(-y ^ +z) { -x }
        }
      }
      Cut()
    }
    Volume {
      Concave {
        Convex {
          Origin { 2.75 * x }
          Plane { -x }
        }
        Origin { width * y + width / 2 * z }
        Origin { -4 * y + -1.5 * z }
        Convex {
          Plane { -y ^ +z }
        }
        Convex {
          Origin { 0.5 * x }
          Plane { -x ^ -y ^ +z }
        }
        Convex {
          Origin { 2 * x + 1 * y }
          Ridge(+y ^ +z) { -x }
        }
      }
      Cut()
    }
    
    // Remove a lone atom that's sticking out with 3 dangling bonds.
    Volume {
      Concave {
        Convex {
          Origin { (width / 2 + 2) * z }
          Plane { +z }
        }
        Convex {
          Origin { 0.25 * x }
          Plane { -x }
        }
      }
      Cut()
    }
  }

  do {
    let width: Float = 18
    housing = Lattice<Cubic> {
      Copy { housing }
      Affine {
        Copy { housing }
        Reflect { y }
        Origin { width / 2 * z }
        Rotate { 0.25 * x }
      }
    }
    housing = Lattice<Cubic> {
      Copy { housing }
      Affine {
        Copy { housing }
        Origin { width / 2 * z }
        Rotate { 0.5 * x }
        
      }
    }
    housing = Lattice<Cubic> {
      Copy { housing }
      Affine {
        Copy { housing }
        Reflect { x }
        Reflect { z }
      }
      Passivate { .hydrogen }
    }
  }
  
  // Make a diamond slab that is superlubricant.
  var rod = Lattice<Cubic> {
    let width: Float = 14
    let thickness: Float = 6
    Material { .carbon }
    Bounds { width * x + width * y + width * z }
    
    Volume {
      Origin { width / 2 * x + width / 2 * y }
      Convex {
        Origin { -1.5 * y }
        Plane { +x ^ -y }
      }
      Convex {
        Origin { 1.5 * y }
        Plane { -x ^ +y }
      }
      Cut()
    }
    Volume {
      Origin { width * x + width * y }
      Convex {
        Origin { -1 * x }
        Plane { +x ^ +y }
      }
      Convex {
        Origin { -1 * x + (thickness - 1.5) * z }
        Plane { -x ^ +y ^ +z }
      }
      Convex {
        Origin { -1 * x + 0.5 * z }
        Plane { -x ^ +y ^ -z }
      }
      Convex {
        Origin { -1 * y + (thickness - 1.5) * z }
        Plane { +x ^ -y ^ +z }
      }
      Convex {
        Origin { -1 * y + 0.5 * z }
        Plane { +x ^ -y ^ -z }
      }
      Convex {
        Origin { (thickness - 2.5) * z }
        Plane { +x ^ +y ^ +z }
      }
      Convex {
        Origin { 1.5 * z }
        Plane { +x ^ +y ^ -z }
      }
      Cut()
    }
  }
  
  rod = Lattice<Cubic> {
    Affine {
      Copy { rod }
      Translate { -4 * x + -4 * y }
    }
    Affine {
      Copy { rod }
      Reflect { x }
      Rotate { 0.25 * z }
    }
  }
  rod = Lattice<Cubic> {
    Copy { rod }
    Affine {
      Copy { rod }
      Translate { -1 * z }
    }
  }
  rod = Lattice<Cubic> {
    for i in 0..<3 {
      Affine {
        Copy { rod }
        Translate { Float(i) * x + Float(-i) * y }
      }
    }
    Volume {
      let thickness: Float = 6
      Convex {
        Origin { (thickness - 0.25) * z }
        Plane { +z }
      }
      Convex {
        Origin { -(thickness - 0.25) * z }
        Plane { -z }
      }
      Replace { .single }
    }
    Passivate { .hydrogen }
  }
  
  // Last steps: casting to Solid and making the assembly
}




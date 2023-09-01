//
//  VdwOscillator.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/28/23.
//

import HDL

public struct VdwOscillator {
  public init() {
    
  }
}

#if false

func vdwOscillator() {
  let (x, y, z) = (Axis.X, Axis.Y, Axis.Z)
  
  // Make a housing, where a solid diamond slab can fit inside it.
  var housing = Solid {
    Lattice { 18 * x; 18 * y; 18 * z }
    
    Convex {
      Origin { width / 2 * z }
      RidgeCut(z) { -y }
      Origin { width * y }
      RidgeCut(z) { +y }
    }
    Convex {
      Origin { width * y; width * z }
      PlaneCut { -y; +z }
    }
    Convex {
      Origin { width / 2 * y; width / 2 * z }
      PlaneCut { -y; -z }
    }
    
    // Add some circular supports on the corners for improved stiffness.
    Convex {
      Origin { width * y; width / 2 * z }
      Concave {
        Origin { -0.5 * y }
        RidgeCut(z) { +y }
        Origin { -2 * y } // -2.5
        PlaneCut { +y }
      }
      Concave {
        Origin { -1 * y }
        RidgeCut(z) { +y }
        Origin { -0.75 * y } // -1.75
        PlaneCut { +y }
      }
      Concave {
        Concave {
          Origin { -thickness * y }
          ValleyCut(z) { -y }
        }
        Concave {
          Origin { -3.75 * y }
          PlaneCut { -y }
          Origin { -1 * y }
          RidgeCut(z) { -y }
        }
      }
    }
    Convex {
      Origin { 20 * x; width * y; width / 2 * z }
      Concave {
        Origin { -0.5 * x; -thickness * y }
        PlaneCut { +x; +y; -z }
      }
      Concave {
        Origin { -0.5 * x }
        PlaneCut { +x; -y; +z }
      }
      Concave {
        PlaneCut { +x; -y; -z }
      }
      Concave {
        Origin { -1 * x; -thickness * y }
        PlaneCut { +x; +y; +z }
      }
    }
    Concave {
      Concave {
        Origin { holeX * x }
        PlaneCut { -x }
      }
      Origin { width * y; width / 2 * z }
      Concave {
        Origin { -2.5 * y; -2 * z }
        PlaneCut { -y; -z }
      }
      Concave {
        Origin { -3.75 * y; -1.75 * z }
        PlaneCut { +y; -z }
      }
      Concave {
        Origin { holeX * x }
        Origin { -4 * y; -1.5 * z }
        PlaneCut { -x; -y; -z }
      }
    }
    Concave {
      Concave {
        Origin { (holeX + 2) * x }
        PlaneCut { -x }
      }
      Origin { width * y; width / 2 * z }
      Origin { -4 * y; -1.5 * z }
      Concave {
        Origin { -4 * y; -1.5 * z }
        PlaneCut { -y; -z }
      }
      Origin { holeX * x }
      Concave {
        PlaneCut { -x; -y; -z }
      }
      Concave {
        Origin { 1 * x; 1 * y }
        RidgeCut(-y, +z) { -x }
      }
    }
    Concave {
      Concave {
        Origin { 2.75 * x }
        PlaneCut { -x }
      }
      Origin { width * y; width / 2 * z }
      Origin { -4 * y; -1.5 * z }
      Concave {
        PlaneCut { -y; +z }
      }
      Concave {
        Origin { 0.5 * x }
        PlaneCut { -x; -y; +z }
      }
      Concave {
        Origin { 2 * x; 1 * y }
        RidgeCut(+y, +z) { -x }
      }
    }
    
    // Remove a lone atom that's sticking out with 3 dangling bonds.
    Concave {
      Concave {
        Origin { (width / 2 + 2) * z }
        PlaneCut { +z }
      }
      Concave {
        Origin { 0.25 * x }
        PlaneCut { -x }
      }
    }
  }
  
  housing = Solid {
    housing()
    Solid {
      housing()
      Reflect(y)
      Origin { width / 2 * z }
      Rotate { 0.25 * x }
    }
  }
  housing = Solid {
    housing()
    Solid {
      housing()
      Origin { width / 2 * z }
      Rotate { 0.5 * x }
    }
  }
  housing = Solid {
    housing()
    Solid {
      housing()
      Reflect(x)
      Reflect(z)
    }
  }
  
  // Make a diamond slab that is superlubricant.
  var rod = Solid {
    Lattice { 14 * x; 14 * y; 14 * z }
    
    Convex {
      Origin { width / 2 * x; width / 2 * y }
      Convex {
        Origin { -1.5 * y }
        PlaneCut { +x; -y }
      }
      Convex {
        Origin { 1.5 * y }
        PlaneCut { -x; +y }
      }
    }
    Convex {
      Origin { width * x; width * y }
      Convex {
        Origin { -1 * x }
        PlaneCut { +x; +y }
      }
      Convex {
        Origin { -1 * x; (widthZ - 1.5) * z }
        PlaneCut { -x; +y; +z }
      }
      Convex {
        Origin { -1 * x; 0.5 * z }
        PlaneCut { -x; +y; -z }
      }
      Convex {
        Origin { -1 * y; (widthZ - 1.5) * z }
        PlaneCut { +x; -y; +z }
      }
      Convex {
        Origin { -1 * y; 0.5 * z }
        PlaneCut { +x; -y; -z }
      }
      Convex {
        Origin { (widthZ - 2.5) * z }
        PlaneCut { +x; +y; +z }
      }
      Convex {
        Origin { 1.5 * z }
        PlaneCut { +x; +y; -z }
      }
    }
    
    Translate { -4 * x; -4 * y }
  }
  
  rod = Solid {
    rod()
    Solid {
      rod()
      Reflect(x)
      Rotate { 0.25 * z }
    }
  }
  rod = Solid {
    rod()
    Solid {
      rod()
      Translate { -1 * z }
    }
  }
  rod = Solid {
    for i in 0..<3 {
      Solid {
        rod()
        Translate { Float(i) * x; Float(-i) * y }
      }
    }
  }
}

#endif

//
//  AtomStatistics.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 4/6/23.
//

#ifndef ATOM_STATISTICS_H
#define ATOM_STATISTICS_H

#include <metal_stdlib>
using namespace metal;

// TODO: Rename this file to "Atom".

struct MRAtomStatistics {
  // Color in RGB color space.
  packed_half3 color;

  // Radius in nm. We don't know the actual radius to 11 bits of precision, so
  // Float16 is fine.
  half radius;
};

struct MRBoundingBox {
  packed_float3 min;
  packed_float3 max;
};

struct MRAtom {
  // Position in nm.
  packed_float3 origin;
  
  // Radius in nm.
  half radiusSquared;
  
  // Atomic number.
  uchar element;
  
  // Flags to modify how the atom is rendered.
  uchar flags;
  
  MRAtom() {
    
  }
  
  MRAtom(constant MRAtomStatistics* atomData,
       float3 origin, uchar element, uchar flags = 0) {
    this->origin = origin;
    this->element = element;
    this->flags = flags;
    
    half radius = this->getRadius(atomData);
    this->radiusSquared = radius * radius;
  }
  
  half getRadius(constant MRAtomStatistics* atomData) {
    return atomData[element].radius;
  }
  
  half3 getColor(constant MRAtomStatistics* atomData) {
    return atomData[element].color;
  }
  
  MRBoundingBox getBoundingBox(constant MRAtomStatistics* atomData) {
    half radius = this->getRadius(atomData);
    auto min = origin - float(radius);
    auto max = origin + float(radius);
    return MRBoundingBox {
      packed_float3(min),
      packed_float3(max)
    };
  }
};

#endif

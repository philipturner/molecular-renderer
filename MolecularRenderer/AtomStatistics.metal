//
//  AtomStatistics.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 4/6/23.
//

#include <metal_stdlib>
using namespace metal;

// (R, G, B, radius_squared)
constexpr constant uint ATOM_DATA_INDEX_OFFSET = 10;
constant half4 neutronData [[function_constant(ATOM_DATA_INDEX_OFFSET + 0)]];
constant half4 hydrogenData [[function_constant(ATOM_DATA_INDEX_OFFSET + 1)]];
constant half4 carbonData [[function_constant(ATOM_DATA_INDEX_OFFSET + 6)]];

struct AtomStatistics {
  // Color in RGB color space.
  packed_half3 color;

  // Radius squared in nm^2. We don't even know this metric to 11 bits of
  // precision, so Float16 is fine.
  half radiusSquared;
};

#define ATOM_STATISTICS_MAKE(x) reinterpret_cast<constant AtomStatistics&>(x)  \

constant AtomStatistics ATOM_DATA[118] = {
  ATOM_STATISTICS_MAKE(neutronData), // 0
  ATOM_STATISTICS_MAKE(hydrogenData), // 1
  ATOM_STATISTICS_MAKE(neutronData), // 2
  ATOM_STATISTICS_MAKE(neutronData), // 3
  ATOM_STATISTICS_MAKE(neutronData), // 4
  ATOM_STATISTICS_MAKE(neutronData), // 5
  ATOM_STATISTICS_MAKE(carbonData), // 6
};

//
//  NewRayTracing.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/17/23.
//

// Unused code; remains here as reference.
#if 0

#include <metal_stdlib>
#include "../Utilities/MRAtom.metal"
using namespace metal;
using namespace raytracing;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused"

namespace metal {
  namespace raytracing {
    class dda;
    
    class grid_intersector;
  };
};

class metal::raytracing::dda {
  ushort3 bounds;
  uint plane_size;
  ushort row_size;
};

class metal::raytracing::grid_intersector {
  dda upper_dda;
  dda lower_dda;
};

#pragma clang diagnostic pop

#endif

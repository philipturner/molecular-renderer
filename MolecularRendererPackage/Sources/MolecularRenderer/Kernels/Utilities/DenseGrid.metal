//
//  DenseGrid.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/24/24.
//

#ifndef DENSE_GRID_H
#define DENSE_GRID_H

#include <metal_stdlib>
#include "Constants.metal"
using namespace metal;

class DenseGrid {
public:
  constant BVHArguments *bvhArgs;
  device uint *data;
  device uint *references;
  device float4 *newAtoms;
};

#endif // DENSE_GRID_H

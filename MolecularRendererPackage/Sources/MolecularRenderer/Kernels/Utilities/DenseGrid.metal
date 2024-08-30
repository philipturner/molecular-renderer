//
//  DenseGrid.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/24/24.
//

#ifndef DENSE_GRID_H
#define DENSE_GRID_H

#include <metal_stdlib>
#include "../Utilities/Constants.metal"
using namespace metal;

class DenseGrid {
public:
  constant BVHArguments *bvhArgs;
  device uint *smallCellMetadata;
  device uint *smallAtomReferences;
  device float4 *convertedAtoms;
};

#endif // DENSE_GRID_H

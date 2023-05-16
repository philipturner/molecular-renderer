//
//  AmbientOcclusion.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 5/15/23.
//

#include <metal_stdlib>
using namespace metal;

// Better implementation at:
// https://github.com/microsoft/DirectX-Graphics-Samples/tree/master/Samples/Desktop/D3D12Raytracing/src/D3D12RaytracingRealTimeDenoisedAmbientOcclusion/RTAO

// TODO: Try using Metal function calls instead of ray query; perhaps it will
// sort rays and avoid the 2.5x divergence.

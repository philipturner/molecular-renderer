//
//  MM4.metal
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/10/23.
//

#include <metal_stdlib>
using namespace metal;

// GPU-accelerated simulator evolved from the Drexler-MM2 forcefield used in
// Nanosystems (1992). Only applies to sp3 hydrocarbons, but achieves hundreds
// of ps/s. Eventually it can be extended to a few more elements.

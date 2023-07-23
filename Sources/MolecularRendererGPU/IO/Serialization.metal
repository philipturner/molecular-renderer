//
//  Serialization.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/23/23.
//

#include <metal_stdlib>
#include "../Utilities/MRAtom.metal"
using namespace metal;

// Each thread processes 4 atoms at once, ensuring all memory transactions
// are 64 bits.

// function to serialize from MRAtom to pre-LZBITMAP

// function to deserialize from post-LZBITMAP to MRAtom

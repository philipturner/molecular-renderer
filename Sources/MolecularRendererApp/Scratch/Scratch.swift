// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

func createCBNTripod() -> [Entity] {
  let output: [Entity] = [
    Entity(position: SIMD3( 0.0027, -0.2608, -0.1439), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1260, -0.2607,  0.0696), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1233, -0.2607,  0.0743), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0032, -0.2166,  0.1503), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0095, -0.0653,  0.1776), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1318, -0.2166, -0.0723), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1586, -0.0653, -0.0806), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1285, -0.2166, -0.0779), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1491, -0.0653, -0.0970), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0000,  0.0203, -0.0000), type: .atom(.germanium)),
    Entity(position: SIMD3( 0.0055, -0.3700, -0.1462), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0031, -0.2241, -0.2462), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2148, -0.2240,  0.1204), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1294, -0.3700,  0.0683), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1238, -0.3699,  0.0779), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2117, -0.2240,  0.1258), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0731, -0.0330,  0.2405), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1020, -0.0418,  0.2303), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1717, -0.0330, -0.1836), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2505, -0.0418, -0.0268), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2448, -0.0330, -0.0570), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1485, -0.0418, -0.2035), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0000,  0.2136, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0000,  0.3334, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1943, -0.4982,  0.5202), type: .atom(.nitrogen)),
    Entity(position: SIMD3(-0.0905, -0.4243,  0.4710), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0240, -0.3986,  0.5463), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0351, -0.4558,  0.6684), type: .atom(.fluorine)),
    Entity(position: SIMD3(-0.2109, -0.3969,  0.2771), type: .atom(.fluorine)),
    Entity(position: SIMD3( 0.0014, -0.2836,  0.2885), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0968, -0.3652,  0.3437), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1242, -0.3174,  0.4988), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1108, -0.2614,  0.3733), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.2123, -0.1802,  0.3358), type: .atom(.fluorine)),
    Entity(position: SIMD3( 0.2118, -0.2969,  0.5580), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2644, -0.5300,  0.4556), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1767, -0.5547,  0.6014), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5476, -0.4982, -0.0919), type: .atom(.nitrogen)),
    Entity(position: SIMD3( 0.4532, -0.4243, -0.1572), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.4611, -0.3986, -0.2939), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.5613, -0.4558, -0.3646), type: .atom(.fluorine)),
    Entity(position: SIMD3( 0.3454, -0.3969,  0.0441), type: .atom(.fluorine)),
    Entity(position: SIMD3( 0.2492, -0.2836, -0.1455), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3461, -0.3653, -0.0880), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3699, -0.3174, -0.3570), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.2679, -0.2614, -0.2826), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1846, -0.1803, -0.3517), type: .atom(.fluorine)),
    Entity(position: SIMD3( 0.3774, -0.2969, -0.4624), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5268, -0.5300,  0.0011), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.6092, -0.5547, -0.1477), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3534, -0.4983, -0.4283), type: .atom(.nitrogen)),
    Entity(position: SIMD3(-0.3627, -0.4243, -0.3139), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4851, -0.3986, -0.2524), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.5964, -0.4558, -0.3038), type: .atom(.fluorine)),
    Entity(position: SIMD3(-0.1345, -0.3970, -0.3212), type: .atom(.fluorine)),
    Entity(position: SIMD3(-0.2506, -0.2836, -0.1431), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2493, -0.3653, -0.2557), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4941, -0.3174, -0.1419), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3787, -0.2614, -0.0907), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3969, -0.1802,  0.0160), type: .atom(.fluorine)),
    Entity(position: SIMD3(-0.5892, -0.2969, -0.0956), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2624, -0.5301, -0.4568), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4325, -0.5547, -0.4537), type: .atom(.hydrogen)),
  ]
  
  return output
}

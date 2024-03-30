import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// WARNING: The renderer could be in 'MRSceneSize.extreme'. If so, it will not
// render any animations.
func createGeometry() -> [Entity] {
  // TODO: Design a new drive wall for the rods, based on the revised design
  // constraints. Get it tested on the AMD GPU before continuing with
  // patterning the logic rods.
  return [Entity(position: .zero, type: .atom(.carbon))]
}

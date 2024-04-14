import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  var probe = Probe()
  probe.project(distance: 2)
  let supply = Supply()
  return probe.createFrame() + supply.createFrame()
}

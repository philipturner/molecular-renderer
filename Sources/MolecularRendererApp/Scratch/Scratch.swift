// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics

func render100Reconstruction() -> [MRAtom] {
  var lattices: [[Entity]] = []
  lattices.append(latticeBasic100())
  lattices.append(latticeAdvanced100())
  lattices.append(latticeSpherical100())
  
  var topologies = lattices
    .map(reconstruct100(_:))
  for i in topologies.indices {
    testTopology(&topologies[i])
  }
  topologies = topologies
    .map(labelCarbonTypes(_:))
  
  var diamondoid = latticeDiamondoid()
  diamondoid.transform { $0.origin.y -= 3 }
  
  var output: [MRAtom] = []
  output += diamondoid.atoms
  output += topologies[0].atoms.map(MRAtom.init)
  output += topologies[1].atoms.map(MRAtom.init).map {
    var copy = $0
    copy.origin.x += 3
    return copy
  }
  output += topologies[2].atoms.map(MRAtom.init).map {
    var copy = $0
    copy.origin.x += 3
    copy.origin.y -= 4.5
    return copy
  }
  return output
}

func testTopology(_ topology: inout Topology) {
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = topology.bonds
  _ = try! MM4Parameters(descriptor: paramsDesc)
  
  var diamondoid = Diamondoid(topology: topology)
  diamondoid.minimize(temperature: 0, fsPerFrame: 1)
  diamondoid.minimize(temperature: 0, fsPerFrame: 100)
  
  for i in topology.atoms.indices {
    topology.atoms[i].position = diamondoid.atoms[i].origin
  }
}

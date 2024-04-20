import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  let cla = CLA()
  let housingDesc = cla.createHousingDescriptor()
  
  let housing = LogicHousing(descriptor: housingDesc)
  print(housing.topology.atoms.count)
  
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = housing.topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = housing.topology.bonds
//  let parameters = try! MM4Parameters(descriptor: paramsDesc)
  
  return housing.topology.atoms
}

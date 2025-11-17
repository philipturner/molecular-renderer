import xTB

final class TightBindingTests {
  func testDiamondSystem122() throws {
    // Set the environment verbosity.
    xTB_Environment.verbosity = .muted
    
    // Select the system.
    let system: [SIMD4<Float>] = diamondSystem122
    
    // Create the calculator.
    var calculatorDesc = xTB_CalculatorDescriptor()
    calculatorDesc.atomicNumbers = system.map { UInt8($0.w) }
    calculatorDesc.positions = system.map {
      SIMD3($0.x, $0.y, $0.z)
    }
    calculatorDesc.hamiltonian = .tightBinding
    let calculator = xTB_Calculator(descriptor: calculatorDesc)
    XCTAssertEqual(calculator.molecule.atomicNumbers.count, 82)
    XCTAssertEqual(calculator.orbitals.count, 196)
    
    // Evaluate the energy.
    XCTAssertEqual(calculator.energy, -452321.592, accuracy: 0.001)
  }
  
  func testDiamondSystem222() throws {
    // Set the environment verbosity.
    xTB_Environment.verbosity = .muted
    
    // Select the system.
    let system: [SIMD4<Float>] = diamondSystem222
    
    // Create the calculator.
    var calculatorDesc = xTB_CalculatorDescriptor()
    calculatorDesc.atomicNumbers = system.map { UInt8($0.w) }
    calculatorDesc.positions = system.map {
      SIMD3($0.x, $0.y, $0.z)
    }
    calculatorDesc.hamiltonian = .tightBinding
    let calculator = xTB_Calculator(descriptor: calculatorDesc)
    XCTAssertEqual(calculator.molecule.atomicNumbers.count, 139)
    XCTAssertEqual(calculator.orbitals.count, 364)
    
    // Evaluate the energy.
    XCTAssertEqual(calculator.energy, -841344.658, accuracy: 0.001)
  }
}

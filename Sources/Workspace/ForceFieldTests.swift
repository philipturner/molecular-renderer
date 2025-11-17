import xTB

final class ForceFieldTests {
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
    calculatorDesc.hamiltonian = .forceField
    let calculator = xTB_Calculator(descriptor: calculatorDesc)
    XCTAssertEqual(calculator.molecule.atomicNumbers.count, 82)
    XCTAssertEqual(calculator.orbitals.count, 0)
    
    // Evaluate the energy.
    XCTAssertEqual(calculator.energy, -57126.394, accuracy: 0.001)
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
    calculatorDesc.hamiltonian = .forceField
    let calculator = xTB_Calculator(descriptor: calculatorDesc)
    XCTAssertEqual(calculator.molecule.atomicNumbers.count, 139)
    XCTAssertEqual(calculator.orbitals.count, 0)
    
    // Evaluate the energy.
    XCTAssertEqual(calculator.energy, -100762.569, accuracy: 0.001)
  }
  
  func testDiamondSystem233() throws {
    // Set the environment verbosity.
    xTB_Environment.verbosity = .muted
    
    // Select the system.
    let system: [SIMD4<Float>] = diamondSystem233
    
    // Create the calculator.
    var calculatorDesc = xTB_CalculatorDescriptor()
    calculatorDesc.atomicNumbers = system.map { UInt8($0.w) }
    calculatorDesc.positions = system.map {
      SIMD3($0.x, $0.y, $0.z)
    }
    calculatorDesc.hamiltonian = .forceField
    let calculator = xTB_Calculator(descriptor: calculatorDesc)
    XCTAssertEqual(calculator.molecule.atomicNumbers.count, 275)
    XCTAssertEqual(calculator.orbitals.count, 0)
    
    // Evaluate the energy.
    XCTAssertEqual(calculator.energy, -208433.751, accuracy: 0.001)
  }
}

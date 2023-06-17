//
//  NobleGasSimulator.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 5/6/23.
//

import Foundation
import QuartzCore
import simd
import MolecularRenderer

// Synchronous single-core CPU simulator that only supports LJ forces. GPU
// implementation is located at:
// https://github.com/philipturner/noble-gas-md-simulation

// NOTE: This is an old fork of the code currently in the URL above. It is only
// maintained here to prototype the OpenMM simulator.

// MARK: - Declaration of Simulator Class

class NobleGasSimulator {
  static var logSimulationSpeed: Bool = true
  static let simulationID: Int = 3 // 0-2
  static let simulationSpeed: Double = 5e-12 // ps/s
  
  fileprivate var ljParametersMap: [Int: LJParameters]
  
  fileprivate var ljParametersPairMap: [AtomPair: LJParameters]
  
  fileprivate var parametersMatrix: LJPotentialParametersMatrix
  
  fileprivate var system: System
  
  fileprivate var frameRate: Int
  
  // The timestep, in seconds.
  fileprivate var timeStep: Double
  
  // The absolute simulation timestamp, in seconds * frameRate.
  fileprivate var absoluteTimeRaw: Double = 0
  
  // The rounded-down time due to discrete time steps, in seconds.
  fileprivate var simulatedTime: Double = 0
  
  init(frameRate: Int, debuggingLJ: Bool = false) {
    self.frameRate = frameRate
    
    #if DEBUG
    print("You must be in Swift release mode to run the simulator.")
    Self.logSimulationSpeed = false
    #endif
    
    self.ljParametersMap = [
      2: LJParameters(sigma: 0.2411, epsilon: 0.732),
      10: LJParameters(sigma: 0.2687, epsilon: 1.371),
      18: LJParameters(sigma: 0.3425, epsilon: 2.189),
      36: LJParameters(sigma: 0.3698, epsilon: 2.916),
    ]
    
    self.ljParametersPairMap = [:]
    for (i, iParameters) in ljParametersMap {
      for (j, jParameters) in ljParametersMap {
        let pair = AtomPair(i: i, j: j)
        var parameters: LJParameters
        
        if i == j {
          parameters = iParameters
        } else {
          let sigma_ii = iParameters.sigma
          let sigma_jj = jParameters.sigma
          
    #if true
          let sigma_ii_3 = sigma_ii * sigma_ii * sigma_ii
          let sigma_jj_3 = sigma_jj * sigma_jj * sigma_jj
          let sigma_6_avg = (
            sigma_ii_3 * sigma_ii_3 + sigma_jj_3 * sigma_jj_3) / 2
          
          let sigma_ij = pow(sigma_6_avg, Double(1.0) / 6)
          var epsilon_ij = sigma_ii_3 * sigma_jj_3 / sigma_6_avg
          epsilon_ij *= sqrt(iParameters.epsilon * jParameters.epsilon)
    #else
          let sigma_ij = (sigma_ii + sigma_jj) / 2
          let epsilon_ij = sqrt(iParameters.epsilon * jParameters.epsilon)
    #endif
          
          parameters = LJParameters(sigma: sigma_ij, epsilon: epsilon_ij)
        }
        
        self.ljParametersPairMap[pair] = parameters
      }
    }
    
    self.parametersMatrix = .init(width: 119, height: 119)
    for i in ljParametersMap.keys {
      for j in ljParametersMap.keys {
        let atomPair = AtomPair(i: i, j: j)
        let parameters = ljParametersPairMap[atomPair]!
        let potentialParameters = LJPotentialParameters(
          sigma: parameters.sigma, epsilon: parameters.epsilon)
        
        let index = parametersMatrix.index(row: i, column: j)
        self.parametersMatrix.setElement(potentialParameters, index: index)
      }
    }
    
    // MARK: - Configuration
    
    // The first 3 systems are ones from the research paper.
    if (0..<3).contains(Self.simulationID) {
      let p_magnitude: Real = 0.3
      let v_magnitude: Real = 0.03
      
      let firstAtomsType: UInt8 = Self.simulationID <= 1 ? 10 : 18
      let secondAtomsType: UInt8 = Self.simulationID <= 0 ? 10 : 18
      let systemAtoms = debuggingLJ ? 2 : 4
      self.system = System(atoms: systemAtoms, ljParameters: parametersMatrix)
      
      // Set atom types.
      let rangeFirst = debuggingLJ ? 0..<1 : 0..<2
      for i in rangeFirst {
        system.setType(firstAtomsType, index: i)
      }
      let rangeSecond = debuggingLJ ? 1..<2 : 2..<4
      for i in rangeSecond {
        system.setType(secondAtomsType, index: i)
      }
      
      if debuggingLJ {
        system.setPosition(SIMD3(-p_magnitude, 0, 0), index: 0)
        system.setPosition(SIMD3( p_magnitude, 0, 0), index: 1)
        system.setVelocity(SIMD3( v_magnitude, 0, 0), index: 0)
        system.setVelocity(SIMD3(-v_magnitude, 0, 0), index: 1)
      } else {
        // Make the atoms move in a spiral.
        let angle = Real.pi * 0.04 // counterclockwise
        let rotationMatrixCol1 = SIMD3<Real>( cos(angle), sin(angle), 0)
        let rotationMatrixCol2 = SIMD3<Real>(-sin(angle), cos(angle), 0)
        let rotationMatrixCol3 = SIMD3<Real>(0, 0, 1)
        
        // Set atom positions and velocities.
        // Avoiding any motion in the Z plane for now.
        for i in 0..<4 {
          let signX: Real = (i % 2 == 0) ? 1 : -1
          let signY: Real = (i / 2 == 0) ? 1 : -1
          
          let distanceScale: Real = p_magnitude // nm
          let position = SIMD3<Real>(
            distanceScale * signX, distanceScale * signY, 0)
          
          let velocityScale: Real = -v_magnitude // nm/ps
          var velocity = SIMD3<Real>(
            velocityScale * signX, velocityScale * signY, 0)
          
          // Rotate the velocity.
          velocity =
          rotationMatrixCol1 * velocity.x +
          rotationMatrixCol2 * velocity.y +
          rotationMatrixCol3 * velocity.z
          
          system.setPosition(position, index: i)
          system.setVelocity(velocity, index: i)
        }
      }
    } else if Self.simulationID == 3 {
      let p_magnitude: Real = 0.4
      let v_magnitude: Real = 0.02
      
      self.system = System(atoms: 26, ljParameters: parametersMatrix)
      
      // Checkerboard pattern of neon and argon.
      var atomID: Int = 0
      for x in -1...1 {
        for y in -1...1 {
          for z in -1...1 {
            if x == 0 && y == 0 && z == 0 {
              continue
            }
            defer { atomID += 1 }
            
            // Neon on faces and corners, argon on edges.
            let isNeon = (x + y + z) % 2 != 0
            system.setType(isNeon ? 10 : 18, index: atomID)

            let position = SIMD3(Real(x), Real(y), Real(z)) * p_magnitude
            let velocity = SIMD3(Real(x), Real(y), Real(z)) * -v_magnitude
            system.setPosition(position, index: atomID)
            system.setVelocity(velocity, index: atomID)
          }
        }
      }
    } else {
      fatalError("Unrecognized simulation ID.")
    }
    
    let femtoseconds: Double = 1.0
    self.timeStep = 1e-15 * femtoseconds
    self.system.initializeAccelerations()
  }
}

extension NobleGasSimulator {
  func updateResources(frameDelta: Int) {
    let (nsPerDay, timeTaken) = self.evolve(
      frameDelta: frameDelta, timeScale: Self.simulationSpeed)
    if Self.logSimulationSpeed {
      let nsRepr = String(format: "%.1f", nsPerDay)
      let ms = timeTaken / 1e-3
      let msRepr = String(format: "%.3f", ms)
      print("\(nsRepr) ns/day, \(msRepr) ms/frame")
    }
  }
  
  // timeScale - simulated seconds per IRL second
  // Returns (ns/day, time taken)
  @discardableResult
  func evolve(frameDelta: Int, timeScale: Double) -> (Double, Double) {
    self.absoluteTimeRaw += Double(frameDelta) * timeScale
    
    let absoluteTime = absoluteTimeRaw / Double(self.frameRate)
    var stepsToSimulate: Int = 0
    var nextSimulatedTime = simulatedTime
    while true {
      nextSimulatedTime += timeStep
      if nextSimulatedTime > absoluteTime {
        break
      }
      simulatedTime = nextSimulatedTime
      stepsToSimulate += 1
    }
    
    let start = CACurrentMediaTime()
    system.evolve(timeStep: timeStep, steps: stepsToSimulate)
    let end = CACurrentMediaTime()
    
    let nanoseconds = Double(stepsToSimulate) * timeStep / 1e-9
    let nsPerDay = nanoseconds * 86400 / (end - start)
    return (nsPerDay, end - start)
  }
  
  func getAtoms() -> [MRAtom] {
    let styles = GlobalStyleProvider.global.styles
    return (0..<system.atoms).map { i in
      // Position is already converted to nm.
      let position = SIMD3<Float>(system.getPosition(index: i))
      let element = system.getType(index: i)
      return MRAtom(styles: styles, origin: position, element: element)
    }
  }
}

// MARK: - Parameters Matrix

// Run the molecular dynamics simulation in FP32 because energy drift is not a
// major issue yet.
fileprivate typealias Real = Float32

// Lennard-Jones parameters in nm and zJ. These will be down-casted to FP32
// when running the molecular dynamics simulation.
fileprivate struct LJParameters {
  var sigma: Double
  var epsilon: Double
}

fileprivate struct AtomPair: Hashable {
  // The smaller element in the pair.
  var lower: Int
  
  // The larger element in the pair.
  var upper: Int
  
  // 'i' and 'j' can be in any order.
  init(i: Int, j: Int) {
    self.lower = min(i, j)
    self.upper = max(i, j)
  }
}

fileprivate struct LJPotentialParameters {
  // 48 * epsilon * sigma^12
  // Units: aJ * nm^12
  var c12: Real
  
  // -24 * epsilon * sigma^6
  // Units: aJ * nm^6
  var c6: Real
  
  // Input sigma in nm, epsilon in zJ.
  init(sigma: Double, epsilon: Double) {
    let sigma2 = sigma * sigma
    let sigma6 = sigma2 * sigma2 * sigma2
    let epsilon_aJ = epsilon * 0.001
    self.c12 = Real(48 * epsilon_aJ * sigma6 * sigma6)
    self.c6 = Real(-24 * epsilon_aJ * sigma6)
  }
}

// Eventually, this should be optimized to use a raw pointer, to avoid bounds
// checking during the inner loop. Another optimization could be to elide the
// matrix entirely, if you can guarantee every atom is of the same element.
fileprivate class LJPotentialParametersMatrix {
  var width: Int
  var height: Int
  var elements: UnsafeMutableBufferPointer<LJPotentialParameters>
  
  init(width: Int, height: Int) {
    self.width = width
    self.height = height
    
    let size = width * height
    let initial = LJPotentialParameters(sigma: 0, epsilon: 0)
    self.elements = .allocate(capacity: size)
    self.elements.initialize(repeating: initial)
  }
  
  func index(row: Int, column: Int) -> Int {
    self.width * row + column
  }
  
  func setElement(_ value: LJPotentialParameters, index: Int) {
    self.elements[index] = value
  }
  
  // A highly performant index into the array.
  @inline(__always)
  func getElement(index: Int, row: Int, column: Int) -> LJPotentialParameters {
    #if DEBUG
    assert(index == row * self.width + column)
    assert(index / self.width == row)
    assert(index % self.width == column)
    assert(row >= 0 && row < self.height)
    assert(column >= 0 && column < self.width)
    let baseAddress = self.elements.baseAddress!
    #else
    let baseAddress = self.elements.baseAddress.unsafelyUnwrapped
    #endif
    
    return baseAddress[index]
  }
}

// MARK: - Simulation

// A very small MD simulation that will not benefit from cutoffs or modern
// optimization algorithms. Computational complexity is O(n^2).
//
// Stores the intermediate data in range-reduced single precision for nonbonded
// force calculations, but expands to double precision (SI units) elsewhere.
//
// WARNING: Make sure to avoid copy-on-write semantics!
fileprivate struct System {
  // The amount of data to store in registers while traversing down the matrix
  // of atom pairs.
  // TODO: Allow differently sized blocks for bonded forces and/or integration.
  typealias Block = SIMD8<Real>
  typealias WideBlock = SIMD8<Double>
  
  // The type used for the self-interaction mask during the inner loop. Use the
  // smallest value possible that fits the required number of atoms.
  typealias Index = UInt16
  typealias IndexBlock = SIMD8<Index>
  typealias AtomicNumberBlock = SIMD8<UInt8>
  
  // Simulation parameters
  var atoms: Int
  var ljParameters: LJPotentialParametersMatrix
  var masses: AtomicMasses
  var accelerationsInitialized: Bool = false
  
  // Atomic number
  private var element: Vector<UInt8>
  
  // Position - nm
  private var x: Vector<Real>
  private var y: Vector<Real>
  private var z: Vector<Real>
  
  // Velocity - nm/ps
  private var v_x: Vector<Real>
  private var v_y: Vector<Real>
  private var v_z: Vector<Real>
  
  // Acceleration - nm/ps/s
  private var a_x: Vector<Real>
  private var a_y: Vector<Real>
  private var a_z: Vector<Real>
  
  // Initialize all the underlying memory. The caller fills in atom positions
  // outside of the loop.
  init(atoms: Int, ljParameters: LJPotentialParametersMatrix) {
    self.atoms = atoms
    self.ljParameters = ljParameters
    self.masses = AtomicMasses()
    
    let align = Block.scalarCount
    
    self.element = .init(repeating: 0, count: atoms, alignment: align)
    
    self.x = .init(repeating: 0, count: atoms, alignment: align)
    self.y = .init(repeating: 0, count: atoms, alignment: align)
    self.z = .init(repeating: 0, count: atoms, alignment: align)
    
    self.v_x = .init(repeating: 0, count: atoms, alignment: align)
    self.v_y = .init(repeating: 0, count: atoms, alignment: align)
    self.v_z = .init(repeating: 0, count: atoms, alignment: align)
    
    self.a_x = .init(repeating: 0, count: atoms, alignment: align)
    self.a_y = .init(repeating: 0, count: atoms, alignment: align)
    self.a_z = .init(repeating: 0, count: atoms, alignment: align)
  }
  
  mutating func initializeAccelerations() {
    // Set the accelerations to something nonzero, so the Verlet integrator can
    // produce something correct on the first iteration.
    self._evolve(timeStep: 0, onlyUpdatingAcceleration: true)
    self.accelerationsInitialized = true
  }
  
  mutating func setType(_ value: UInt8, index: Int) {
    element.setElement(value, index: index)
  }
  
  mutating func getType(index: Int) -> UInt8 {
    return element.getElement(index: index)
  }
  
  mutating func setPosition(_ value: SIMD3<Real>, index: Int) {
    x.setElement(value.x, index: index)
    y.setElement(value.y, index: index)
    z.setElement(value.z, index: index)
  }
  
  mutating func getPosition(index: Int) -> SIMD3<Real> {
    return SIMD3(
      x.getElement(index: index),
      y.getElement(index: index),
      z.getElement(index: index)
    )
  }
  
  mutating func setVelocity(_ value: SIMD3<Real>, index: Int) {
    v_x.setElement(value.x, index: index)
    v_y.setElement(value.y, index: index)
    v_z.setElement(value.z, index: index)
  }
  
  mutating func getVelocity(index: Int) -> SIMD3<Real> {
    return SIMD3(
      v_x.getElement(index: index),
      v_y.getElement(index: index),
      v_z.getElement(index: index)
    )
  }
}

extension System {
  mutating func description(atomRange: Range<Int>) -> String {
    func fmt(_ value: Real) -> String {
      String(format: "%.3f", value)
    }
    func fmt(_ value: SIMD3<Real>) -> String {
      "[\(fmt(value.x)), \(fmt(value.y)), \(fmt(value.z))]"
    }
    
    var output: String = ""
    for i in atomRange {
      let type = getType(index: i)
      let position = getPosition(index: i)
      let velocity = getVelocity(index: i)
      output.append("Z=\(type)\t ")
      output.append("p = \(fmt(position))\t nm ")
      output.append("v = \(fmt(velocity))\t nm/ps")
      output.append("\n")
    }
    if output.count > 0 {
      // Remove the last newline.
      output.removeLast(1)
    }
    return output
  }
}

extension System {
  // This operation has perfect elementwise parallelism. An advanced
  // implementation could try parallelizing across multiple CPU cores.
  //
  // 'timesStep' is in seconds.
  mutating func evolve(timeStep h: Double, steps: Int = 1) {
    precondition(accelerationsInitialized)
    for _ in 0..<steps {
      self._evolve(timeStep: h)
    }
  }
  
  // Returns energy in joules.
  mutating func getEnergy() -> (kinetic: Double, potential: Double) {
    precondition(accelerationsInitialized)
    var kinetic: Double = 0
    var potential: Double = 0
    self._evolve(
      timeStep: 0, queryEnergy: true, kineticEnergy: &kinetic,
      potentialEnergy: &potential)
    return (kinetic, potential)
  }
  
  // Returns the energy after the time step has finished. If querying energy, do
  // not update any state variables.
  @inline(__always)
  private mutating func _evolve(
    timeStep h: Double,
    onlyUpdatingAcceleration: Bool = false,
    queryEnergy: Bool = false,
    kineticEnergy: UnsafeMutablePointer<Double>? = nil,
    potentialEnergy: UnsafeMutablePointer<Double>? = nil
  ) {
    let loopWidth = Block.scalarCount
    var i1 = 0 // initial i; do not modify this later
    while i1 < atoms {
      defer { i1 += loopWidth }
      
      // Some numbers are stored in SI units, while others values are
      // range-reduced to fit single precision. Any range-reduced numbers should
      // be explicitly labeled.
      
      // nm: 1e-9
      let x_curr = x.getElement(type: Block.self, actualIndex: i1)
      let y_curr = y.getElement(type: Block.self, actualIndex: i1)
      let z_curr = z.getElement(type: Block.self, actualIndex: i1)
      
      // nm/ps: 1e3
      let v_x_curr = v_x.getElement(type: Block.self, actualIndex: i1)
      let v_y_curr = v_y.getElement(type: Block.self, actualIndex: i1)
      let v_z_curr = v_z.getElement(type: Block.self, actualIndex: i1)
      
      // nm/ps/s: 1e3
      // NOTE: nm/ps/s could be very off. I may need a larger/smaller unit.
      let a_x_curr = a_x.getElement(type: Block.self, actualIndex: i1)
      let a_y_curr = a_y.getElement(type: Block.self, actualIndex: i1)
      let a_z_curr = a_z.getElement(type: Block.self, actualIndex: i1)
      
      // Apply velocity Verlet integrator.
      
      // m: 1e0
      let nm___m: Double = 1e-9
      var x_next = nm___m * WideBlock(x_curr)
      var y_next = nm___m * WideBlock(y_curr)
      var z_next = nm___m * WideBlock(z_curr)
      
      let nm_ps___m_s: Double = 1e3
      x_next += nm_ps___m_s * h * WideBlock(v_x_curr)
      y_next += nm_ps___m_s * h * WideBlock(v_y_curr)
      z_next += nm_ps___m_s * h * WideBlock(v_z_curr)
      
      let nm_ps_s___m_s2: Double = 1e3
      let multiplier: Double = 0.5 * h * h
      x_next += nm_ps_s___m_s2 * multiplier * WideBlock(a_x_curr)
      y_next += nm_ps_s___m_s2 * multiplier * WideBlock(a_y_curr)
      z_next += nm_ps_s___m_s2 * multiplier * WideBlock(a_z_curr)
      
      // nm: 1e-9
      let m___nm: Double = 1e9
      let x_i = Block(x_next * m___nm)
      let y_i = Block(y_next * m___nm)
      let z_i = Block(z_next * m___nm)
      
      // Update the positions *before* calculating forces.
      if !queryEnergy && !onlyUpdatingAcceleration {
        self.x.setElement(x_i, type: Block.self, actualIndex: i1)
        self.y.setElement(y_i, type: Block.self, actualIndex: i1)
        self.z.setElement(z_i, type: Block.self, actualIndex: i1)
      }
    }
    
    // TODO: Add autotuning functionality so it chooses the optimal number of
    // cores automatically, but without sacrificing performance for extremely
    // small simulations.
    let numCores = 1
    
    func execute(coreID: Int) {
      var i2 = loopWidth * coreID
      while i2 < atoms {
        defer { i2 += loopWidth * numCores }
        
        // nm: 1e-9
        let x_i = x.getElement(type: Block.self, actualIndex: i2)
        let y_i = y.getElement(type: Block.self, actualIndex: i2)
        let z_i = z.getElement(type: Block.self, actualIndex: i2)
        
        // nm/ps: 1e3
        let v_x_curr = v_x.getElement(type: Block.self, actualIndex: i2)
        let v_y_curr = v_y.getElement(type: Block.self, actualIndex: i2)
        let v_z_curr = v_z.getElement(type: Block.self, actualIndex: i2)
        
        // nm/ps/s: 1e3
        let a_x_curr = a_x.getElement(type: Block.self, actualIndex: i2)
        let a_y_curr = a_y.getElement(type: Block.self, actualIndex: i2)
        let a_z_curr = a_z.getElement(type: Block.self, actualIndex: i2)
        
        // Generate a coordinate vector of indices.
        var indexInList: IndexBlock = .zero
        for k in 0..<Block.scalarCount {
          indexInList[k] = Index(i2 + k)
        }
        
        // Atomic number
        let id = element.getElement(
          type: AtomicNumberBlock.self, actualIndex: i2)
        
        // nN: 1e-9
        var f_x_next: Block = .zero
        var f_y_next: Block = .zero
        var f_z_next: Block = .zero
        
        // aJ: 1e-18, but needs to be scaled by 1/12
        var u_next: Block = .zero
        
        // Find new acceleration and update velocities.
        defer {
          // kg: 1e0
          var mass: WideBlock = .zero
          id.forEachElement { i, element in
            mass[i] = self.masses.getMass(atomicNumber: element)
          }
          
          // kg^-1: 1e0
          let inverseMass = simd_precise_recip(mass)
          
          // m/s^2: 1e0
          let nm_s2___m_s2: Double = 1e-9
          let a_x_next = nm_s2___m_s2 * inverseMass * WideBlock(f_x_next)
          let a_y_next = nm_s2___m_s2 * inverseMass * WideBlock(f_y_next)
          let a_z_next = nm_s2___m_s2 * inverseMass * WideBlock(f_z_next)
          
          // Store the next accelerations.
          if !queryEnergy {
            // nm/ps/s: 1e3
            let m_s2___nm_ps_s: Double = 1e-3
            let _a_x_next = Block(a_x_next * m_s2___nm_ps_s)
            let _a_y_next = Block(a_y_next * m_s2___nm_ps_s)
            let _a_z_next = Block(a_z_next * m_s2___nm_ps_s)
            self.a_x.setElement(_a_x_next, type: Block.self, actualIndex: i2)
            self.a_y.setElement(_a_y_next, type: Block.self, actualIndex: i2)
            self.a_z.setElement(_a_z_next, type: Block.self, actualIndex: i2)
          }
          
          // Average the accelerations.
          // The current value is twice the average acceleration. A later line of
          // code will correct for the factor of 2.
          let nm_ps_s___m_s2: Double = 1e3
          let a_x_sum = a_x_next + nm_ps_s___m_s2 * WideBlock(a_x_curr)
          let a_y_sum = a_y_next + nm_ps_s___m_s2 * WideBlock(a_y_curr)
          let a_z_sum = a_z_next + nm_ps_s___m_s2 * WideBlock(a_z_curr)
          
          // nm/ps: 1e3
          let nm_ps___m_s: Double = 1e3
          var v_x_next = nm_ps___m_s * WideBlock(v_x_curr)
          var v_y_next = nm_ps___m_s * WideBlock(v_y_curr)
          var v_z_next = nm_ps___m_s * WideBlock(v_z_curr)
          
          let multiplier: Double = 0.5 * h
          v_x_next += multiplier * a_x_sum
          v_y_next += multiplier * a_y_sum
          v_z_next += multiplier * a_z_sum
          
          if queryEnergy {
            var v2 = v_x_next * v_x_next
            v2.addProduct(v_y_next, v_y_next)
            v2.addProduct(v_z_next, v_z_next)
            
            let kineticProduct = 0.5 * mass * v2
            var kineticSum: Double = 0
            for k in 0..<min(Block.scalarCount, atoms - i2) {
              kineticSum += kineticProduct[k]
            }
            kineticEnergy!.pointee += kineticSum
            
            // aJ: 1e-18
            let aJ___J: Double = 1e-18
            
            // This doesn't make any sense - apparently the potential energy is
            // attributed to a pair of particles. But, the force is applied twice
            // - once to particle i, another time to particle j. That means the
            // force (derivative of U) is applied twice:
            //
            // F = -delta U / delta r
            // F = F_i = -F_j
            // new U = U - F_i * delta r - (-F_j) * delta (-r)
            //
            // assume both particles are the same and |F_i| = |F_j|
            // new U = U - 2 * F * delta r
            // new U = U + 2 * delta U
            // new U - U = 2 * delta U
            // delta U = 2 * delta U
            //
            // U = 2U ?????????????????????????
            //
            // For some reason, this formula works, even though the math doesn't
            // seem to work out.
            let multiplier = aJ___J / 12 / 2
            let potentialProduct = multiplier * WideBlock(u_next)
            var potentialSum: Double = 0
            for k in 0..<min(Block.scalarCount, atoms - i2) {
              potentialSum += potentialProduct[k]
            }
            potentialEnergy!.pointee += potentialSum
          }
          
          if !queryEnergy && !onlyUpdatingAcceleration {
            // TODO: Implement a good thermostat. Modify the velocities before
            // the next time step, so they remain at the right temperature.
            
            // nm/ps: 1e3
            let m_s___nm_ps: Double = 1e-3
            let _v_x_next = Block(v_x_next * m_s___nm_ps)
            let _v_y_next = Block(v_y_next * m_s___nm_ps)
            let _v_z_next = Block(v_z_next * m_s___nm_ps)
            self.v_x.setElement(_v_x_next, type: Block.self, actualIndex: i2)
            self.v_y.setElement(_v_y_next, type: Block.self, actualIndex: i2)
            self.v_z.setElement(_v_z_next, type: Block.self, actualIndex: i2)
          }
        }
        
        var parameterIndexBase: IndexBlock = .zero
        id.forEachElement { i, element in
          parameterIndexBase[i] = Index(
            self.ljParameters.index(row: Int(element), column: 0))
        }
        
        // Calculate nonbonded forces.
        for j in 0..<Index(atoms) {
          let id_j = element.getElement(index: Int(j))
          
          // C12 = 48 * epsilon * sigma^12
          // C6 = -24 * epsilon * sigma^6
          
          // aJ * nm^12: 1e-126
          var c12: Block = .zero
          
          // aJ * nm^6: 1e-72
          var c6: Block = .zero
          
          // NOTE: If simulating only one element, you can elide the parameter
          // query, leading to a significant speedup.
          let matrixIndex = parameterIndexBase &+ Index(id_j)
          for k in 0..<Block.scalarCount {
            let index = matrixIndex[k]
            let parameters = self.ljParameters.getElement(
              index: Int(index), row: Int(id[k]), column: Int(id_j))
            c12[k] = parameters.c12
            c6[k] = parameters.c6
          }
          
          // TODO: Maybe store positions in both split and interleaved formats to
          // reduce the number of memory instructions here. All three memory
          // accesses can be issued in a single cycle, so the optimization might
          // complicate things and backfire.
          let x_j = self.x.getElement(index: Int(j))
          let y_j = self.y.getElement(index: Int(j))
          let z_j = self.z.getElement(index: Int(j))
          
          // Order of subtraction: if LJ force is positive, we should push the
          // Particles away from each other. Take particle i's position, and
          // subtract particle j's position. Then, normalize the delta. This is
          // the direction where the force acts. The quantity F/r normalizes for
          // you while making the force calculation cheaper.
          //
          // Also note that by Newton's third law, the force will be duplicated.
          // From particle j's point of view, particle i is pushed with double the
          // acceleration derived from -dU/dr. This can be explained by the
          // following:
          //
          // Each particle has its own potential energy, independent from the
          // other interacting particle. The PES curves happen to look the same,
          // but they're two separate potential energies for two separate
          // particles. -dU/dr for particle i is coming out of U_i. -dU/dr for
          // particle j is coming out of U_j. If they came out of the same
          // potential energy function, then you'd be correct that the potential
          // energy delta is being duplicated.
          //
          // nm: 1e-9
          let x_delta = x_i - x_j
          let y_delta = y_i - y_j
          let z_delta = z_i - z_j
          
          // nm^-2: 1e18
          var r2 = x_delta * x_delta
          r2.addProduct(y_delta, y_delta)
          r2.addProduct(z_delta, z_delta)
          r2 = simd_fast_recip(r2)
          
          // Check whether j == index. If so, skip the iteration.
          let upcasted = Block.MaskStorage(truncatingIfNeeded: indexInList)
          r2.replace(with: .zero, where: upcasted .== Real.SIMDMaskScalar(j))
          
          // nm^-6: 1e54
          let r6 = r2 * r2 * r2
          
          // nm^-12: 1e108
          let r12 = r6 * r6
          
          // aJ: 1e-18
          var temp1 = c6 * r6
          if queryEnergy {
            u_next.addProduct(temp1, 2)
            u_next.addProduct(c12, r12)
          }
          temp1.addProduct(c12, r12)
          
          // aJ * nm^-2: 1e0
          // 10^-18 * (kg * m^2/s^2) * nm^-2
          // 10^-18 * (kg/s^2) * 10^18
          let temp2 = temp1 * r2
          
          // aJ/nm: 1e-9
          // nano-Newtons
          f_x_next.addProduct(temp2, x_delta)
          f_y_next.addProduct(temp2, y_delta)
          f_z_next.addProduct(temp2, z_delta)
        }
      }
    }
    
    if numCores == 1 {
      execute(coreID: 0)
    } else {
      // Profile CPU synchronization latency.
      let loggingLatency = false
      let start = loggingLatency ? CACurrentMediaTime() : 0
      DispatchQueue.concurrentPerform(iterations: numCores, execute: execute)
      let end = loggingLatency ? CACurrentMediaTime() : 0
      if loggingLatency {
        print("\((end - start) / 1e-6) us")
      }
    }
  }
}

// MARK: - Boilerplate code for VectorBlock implementation

protocol VectorBlock {
  associatedtype Scalar
  
  static var scalarCount: Int { get }
  
  static var zero: Self { get }
  
  func forEachElement(_ closure: (Int, Scalar) -> Void)
}

extension UInt8: VectorBlock {
  static var scalarCount: Int { 1 }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Self) -> Void) { closure(0, self) }
}

extension Float: VectorBlock {
  static var scalarCount: Int { 1 }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Self) -> Void) { closure(0, self) }
}

extension Double: VectorBlock {
  static var scalarCount: Int { 1 }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Self) -> Void) { closure(0, self) }
}

extension SIMD2: VectorBlock where Scalar: VectorBlock {
  static var zero: Self { .init(repeating: .zero) }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Scalar) -> Void) {
    for i in 0..<scalarCount {
      closure(i, self[i])
    }
  }
}

extension SIMD4: VectorBlock where Scalar: VectorBlock {
  static var zero: Self { .init(repeating: .zero) }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Scalar) -> Void) {
    for i in 0..<scalarCount {
      closure(i, self[i])
    }
  }
}

extension SIMD8: VectorBlock where Scalar: VectorBlock {
  static var zero: Self { .init(repeating: .zero) }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Scalar) -> Void) {
    for i in 0..<scalarCount {
      closure(i, self[i])
    }
  }
}

extension SIMD16: VectorBlock where Scalar: VectorBlock {
  static var zero: Self { .init(repeating: .zero) }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Scalar) -> Void) {
    for i in 0..<scalarCount {
      closure(i, self[i])
    }
  }
}

extension SIMD32: VectorBlock where Scalar: VectorBlock {
  static var zero: Self { .init(repeating: .zero) }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Scalar) -> Void) {
    for i in 0..<scalarCount {
      closure(i, self[i])
    }
  }
}

extension SIMD64: VectorBlock where Scalar: VectorBlock {
  static var zero: Self { .init(repeating: .zero) }
  
  @inline(__always)
  func forEachElement(_ closure: (Int, Scalar) -> Void) {
    for i in 0..<scalarCount {
      closure(i, self[i])
    }
  }
}

// WARNING: Make sure to avoid copy-on-write semantics!
struct Vector<T> {
  var count: Int
  var alignedCount: Int
  private(set) var elements: [T]
  var bufferPointer: UnsafeMutableBufferPointer<T>
  
  init(repeating repeatedValue: T, count: Int, alignment: Int) {
    self.count = count
    self.alignedCount = ~(alignment - 1) & (count + alignment - 1)
    self.elements = Array(repeating: repeatedValue, count: alignedCount)
    self.bufferPointer = elements.withUnsafeMutableBufferPointer { $0 }
  }
  
  // A highly performant index into the array.
  @inline(__always)
  mutating func setElement(_ value: T, index: Int) {
    #if DEBUG
    elements.withUnsafeMutableBufferPointer { bufferPointer in
      assert(index >= 0 && index < self.count)
      assert(self.bufferPointer.baseAddress == bufferPointer.baseAddress)
      assert(self.bufferPointer.count == bufferPointer.count)
    }
    let baseAddress = self.bufferPointer.baseAddress!
    #else
    let baseAddress = self.bufferPointer.baseAddress.unsafelyUnwrapped
    #endif

    baseAddress[index] = value
  }
  
  // A highly performant index into the array.
  @inline(__always)
  mutating func setElement<
    U: VectorBlock
  >(_ value: U, type: U.Type, actualIndex: Int) {
    #if DEBUG
    elements.withUnsafeMutableBufferPointer { bufferPointer in
      assert(actualIndex >= 0 && actualIndex < self.count)
      assert(self.bufferPointer.baseAddress == bufferPointer.baseAddress)
      assert(self.bufferPointer.count == bufferPointer.count)
      assert(actualIndex % U.scalarCount == 0)
    }
    let baseAddress = self.bufferPointer.baseAddress!
    #else
    let baseAddress = self.bufferPointer.baseAddress.unsafelyUnwrapped
    #endif

    let castedAddress = unsafeBitCast(
      baseAddress + actualIndex, to: UnsafeMutablePointer<U>.self)
    castedAddress.pointee = value
  }
  
  // A highly performant index into the array.
  @inline(__always)
  mutating func getElement(index: Int) -> T {
    #if DEBUG
    elements.withUnsafeMutableBufferPointer { bufferPointer in
      assert(index >= 0 && index < self.count)
      assert(self.bufferPointer.baseAddress == bufferPointer.baseAddress)
      assert(self.bufferPointer.count == bufferPointer.count)
    }
    let baseAddress = self.bufferPointer.baseAddress!
    #else
    let baseAddress = self.bufferPointer.baseAddress.unsafelyUnwrapped
    #endif
    
    return baseAddress[index]
  }
  
  // A highly performant index into the array.
  @inline(__always)
  mutating func getElement<
    U: VectorBlock
  >(type: U.Type, actualIndex: Int) -> U {
    #if DEBUG
    elements.withUnsafeMutableBufferPointer { bufferPointer in
      assert(actualIndex >= 0 && actualIndex < self.count)
      assert(self.bufferPointer.baseAddress == bufferPointer.baseAddress)
      assert(self.bufferPointer.count == bufferPointer.count)
      assert(actualIndex % U.scalarCount == 0)
    }
    let baseAddress = self.bufferPointer.baseAddress!
    #else
    let baseAddress = self.bufferPointer.baseAddress.unsafelyUnwrapped
    #endif

    let castedAddress = unsafeBitCast(
      baseAddress + actualIndex, to: UnsafeMutablePointer<U>.self)
    return castedAddress.pointee
  }
}

//
//  MM4RigidBody+Temperature.swift
//  MM4
//
//  Created by Philip Turner on 11/20/23.
//

// WARNING: This file will not compile. It mostly serves to inform the reader on
// how thermal velocities are computed.

import Foundation

// TODO: Consider making velocities mutable and moving this into the hardware
// catalog. While at the same time, avoiding the compute cost of reinitializing
// velocities every time the rigid body is updated.

/// 0.008314
public let MM4BoltzInKJPerMolPerK: Double = 8.314462618 / 1000

/// 0.013806
public let MM4BoltzInZJPerK: Double = 8.314462618 / 1000 * MM4ZJPerKJPerMol

extension MM4RigidBody {
  /// Set the thermal kinetic energy to match a given temperature, assuming
  /// positions are energy-minimized at 0 K.
  ///
  /// - Parameter temperature: The temperature to match the thermal energy to,
  ///   in kelvin.
  /// - Parameter heatCapacity: The partitioning of overall thermal energy in
  ///   thermodynamic units per atom (kT or R). The default value is 1.5.
  ///
  /// Some of the energy will be lost to thermal potential energy during a
  /// simulation. This information can technically be recovered from the atoms'
  /// positions. Typical use cases minimize the system at 0 K, then initialize
  /// the simulator at room temperature. It is not anticipated that users will
  /// extract temperature (e.g. local temperature differentials) from the
  /// simulation.
  ///
  /// > WARNING: There is no trivial method to translate between thermal energy
  /// and temperature. Therefore, you must find a heat capacity lookup table
  /// from an external source. Diamond has
  /// [significantly different](https://physics.stackexchange.com/a/583043) heat
  /// capacity characteristics than other solids. In 1957, C. V. Raman devised a
  /// [theoretical function](http://dspace.rri.res.in/bitstream/2289/1763/1/1957%20Proc%20Indian%20Acad%20Sci%20A%20V46%20p323-332.pdf)
  /// to map temperature to heat capacity for diamond. Experimental measurements
  /// matched the prediction with around 1% margin of error.
  ///
  /// Heat capacity in kT/atom equals the value in J/mol-K divided by 8.314. For
  /// reference, here are some common heat capacities:
  /// - By the equipartition theorem, ideal gases are 1.5 kT.
  /// - Most crystalline solids approach 3.0 kT at high temperatures.
  /// - Diamond: 0.74 kT at 298 K, 1.62 kT at 500 K ([Raman, 1957](http://dspace.rri.res.in/bitstream/2289/1763/1/1957%20Proc%20Indian%20Acad%20Sci%20A%20V46%20p323-332.pdf)).
  /// - Moissanite: 1.62 kT at 298 K, 2.31 kT at 500 K ([Chekhovskoy, 1971](https://doi.org/10.1016/S0021-9614(71)80045-9)).
  /// - Silicon: 2.41 kT at 298 K, 2.84 kT at 500 K ([Desai, 1985](https://srd.nist.gov/JPCRD/jpcrd298.pdf)).
  ///
  /// ![Material Heat Capacities](MaterialHeatCapacities)
  public mutating func setThermalKineticEnergy(
    temperature: Float,
    heatCapacity: Float = 1.5
  ) {
    // Change the thermal velocities regardless of whether the previous thermal
    // energy was the same as the new value. This design choice reduces the
    // number of edge cases that must be tested.
    ensureUniquelyReferenced()
    storage.velocities = nil
    
    // E = thermal energy
    // C = heat capacity
    // N = number of atoms, excluding those with zero mass
    // k = Boltzmann constant
    // T = temperature
    //
    // E = N C kT
    
    let kT = Float(MM4BoltzInZJPerK) * temperature
    let particleEnergy = heatCapacity * kT
    storage.createThermalVelocities(particleEnergy: particleEnergy)
  }
}

extension MM4RigidBodyStorage {
  func createThermalVelocities(particleEnergy: Float) {
    ensureCenterOfMassCached()
    ensureLinearVelocityCached()
    ensureAngularVelocityCached()
    
    // Express that every bulk quantity, except thermal kinetic energy, is the
    // same as before thermalization.
    guard let centerOfMass,
          let constantLinearVelocity = linearVelocity,
          let constantAngularVelocity = angularVelocity else {
      fatalError("This should never happen.")
    }
    
    // Handle the special case where velocity rescaling will certainly cause
    // division by zero.
    if atoms.nonAnchorCount == 0 {
      return
    }
    
    // Preserve the velocities of anchor atoms.
    let preservedVelocities = vVelocities
    
    // Reference implementation from OpenMM.
    /*
     // Generate the list of Gaussian random numbers.
     OpenMM_SFMT::SFMT sfmt;
     init_gen_rand(randomSeed, sfmt);
     std::vector<double> randoms;
     while (randoms.size() < system.getNumParticles()*3) {
     double x, y, r2;
     do {
     x = 2.0*genrand_real2(sfmt)-1.0;
     y = 2.0*genrand_real2(sfmt)-1.0;
     r2 = x*x + y*y;
     } while (r2 >= 1.0 || r2 == 0.0);
     double multiplier = sqrt((-2.0*std::log(r2))/r2);
     randoms.push_back(x*multiplier);
     randoms.push_back(y*multiplier);
     }
     
     // Assign the velocities.
     std::vector<Vec3> velocities(system.getNumParticles(), Vec3());
     int nextRandom = 0;
     for (int i = 0; i < system.getNumParticles(); i++) {
     double mass = system.getParticleMass(i);
     if (mass != 0) {
     double velocityScale = sqrt(BOLTZ*temperature/mass);
     velocities[i] = Vec3(randoms[nextRandom++], randoms[nextRandom++], randoms[nextRandom++])*velocityScale;
     }
     }
     return velocities;
     */
    @_transparent
    func gaussian(_ seed: MM4UInt32Vector) -> (
      x: MM4FloatVector, y: MM4FloatVector, r2: MM4FloatVector
    ) {
      let seedPair = unsafeBitCast(seed, to: MM4UInt16VectorPair.self)
      let floatPair = MM4FloatVectorPair(seedPair) / Float(UInt16.max)
      let x = 2 * floatPair.evenHalf - 1
      let y = 2 * floatPair.oddHalf - 1
      let r2 = x * x + y * y
      return (x, y, r2)
    }
    
    // First, generate a unitless list of velocities. Pad the list to 64 more
    // than required (21 atoms) to decrease the overhead of repeated
    // reinitialization in the final loop iterations.
    var scalarsRequired = 3 * atoms.vectorCount * MM4VectorWidth
    scalarsRequired = (scalarsRequired + 4 - 1) / 4 * 4
    let scalarsCapacity = 64 + scalarsRequired
    let scalarsPointer: UnsafeMutablePointer<UInt16> =
      .allocate(capacity: scalarsCapacity)
    defer { scalarsPointer.deallocate() }
    
    // Repeatedly compact the list, removing pairs that failed.
    var scalarsFinished = 0
    var generator = SystemRandomNumberGenerator()
    while scalarsFinished < scalarsRequired {
      // Round down to UInt64 alignment.
      scalarsFinished = scalarsFinished / 4 * 4
      
      // Fill up to the capacity, rather than the required amount.
      let quadsToGenerate = (scalarsCapacity - scalarsFinished) / 4
      let quadsPointer: UnsafeMutablePointer<UInt64> = .init( OpaquePointer(scalarsPointer + scalarsFinished / 4))
      for i in 0..<quadsToGenerate {
        quadsPointer[i] = generator.next()
      }
      
      // The first of these pointers acts as a cursor.
      var pairsPointer: UnsafeMutablePointer<UInt32> = .init( OpaquePointer(scalarsPointer + scalarsFinished / 4))
      let pairsVectorPointer: UnsafeMutablePointer<MM4UInt32Vector> = .init( OpaquePointer(scalarsPointer + scalarsFinished / 4))
      
      for vID in 0..<quadsToGenerate * 4 / MM4VectorWidth {
        let seed = pairsVectorPointer[vID]
        let (_, _, r2) = gaussian(seed)
        
        let mask = (r2 .< 1) .& (r2 .!= 0)
        for lane in 0..<MM4VectorWidth {
          if mask[lane] {
            pairsPointer.pointee = seed[lane]
            pairsPointer += 1
          }
        }
      }
      let newScalarsPointer: UnsafeMutablePointer<UInt16> = .init(
        OpaquePointer(pairsPointer))
      scalarsFinished = newScalarsPointer - scalarsPointer
    }
    
    // Generate velocities, zeroing out the ones from anchors.
    //
    // E_particle = E_system / (atoms.count - anchors.count)
    // E_openmm = 3/2 kT
    // kT = 2/3 * (translational kinetic energy)
    //
    // mass = anchor ? INF : mass
    // v_rms = sqrt(2/3 * E_particle / mass)
    // v = (gaussian(0, 1), gaussian(0, 1), gaussian(0, 1)) * v_rms
    let xyPointer: UnsafePointer<MM4UInt32Vector> = .init(
      OpaquePointer(scalarsPointer))
    let zPointer: UnsafePointer<MM4UInt16Vector> = .init(
      OpaquePointer(scalarsPointer + 2 * MM4VectorWidth * atoms.vectorCount))
    let particleEnergyTerm = (2.0 / 3) * particleEnergy
    
    for vID in 0..<atoms.vectorCount {
      var xGaussian: MM4FloatVector
      var yGaussian: MM4FloatVector
      var zGaussian: MM4FloatVector
      do {
        let z = MM4FloatVector(zPointer[vID]) / Float(UInt16.max)
        let zLow = 2 * z.evenHalf - 1
        let zHigh = 2 * z.oddHalf - 1
        let zR2 = zLow * zLow + zHigh * zHigh
        let (x, y, xyR2) = gaussian(xyPointer[vID])
        var (xyLog, zLog) = (xyR2, zR2)
        
        // There is no simple way to access vectorized transcendentals on
        // non-Apple platforms. Ideally, one would copy code from Sleef. We
        // can only keep our fingers crossed that the compiler will
        // "auto-vectorize" this transcendental function, which may have
        // control flow operations that prevent it from actually vectorizing.
        for lane in 0..<MM4VectorWidth {
          xyLog[lane] = log(xyLog[lane])
        }
        for lane in 0..<MM4VectorWidth / 2 {
          zLog[lane] = log(zLog[lane])
        }
        
        let xyMultiplier = (-2 * xyLog / xyR2).squareRoot()
        let zMultiplier = (-2 * zLog / zR2).squareRoot()
        xGaussian = x * xyMultiplier
        yGaussian = y * xyMultiplier
        
        var zBroadcasted: MM4FloatVector = .zero
        zBroadcasted.evenHalf = zMultiplier
        zBroadcasted.oddHalf = zMultiplier
        zGaussian = z * zBroadcasted
      }
      
      var mass = vMasses[vID]
      mass.replace(with: .greatestFiniteMagnitude, where: mass .== 0)
      let velocityScale = (particleEnergyTerm / mass).squareRoot()
      vVelocities[vID &* 3 &+ 0] = xGaussian * velocityScale
      vVelocities[vID &* 3 &+ 1] = yGaussian * velocityScale
      vVelocities[vID &* 3 &+ 2] = zGaussian * velocityScale
    }
    
    // Query the bulk linear and angular momentum.
    let linearDrift = createLinearVelocity()
    let wDrift = createAngularVelocity()
    
    // Set momentum to zero and calculate the modified thermal energy.
    var correctedThermalKineticEnergy: Double = .zero
    withSegmentedLoop(chunk: 256) {
      var vKineticX: MM4FloatVector = .zero
      var vKineticY: MM4FloatVector = .zero
      var vKineticZ: MM4FloatVector = .zero
      for vID in $0 {
        let rX = vPositions[vID &* 3 &+ 0] - centerOfMass.x
        let rY = vPositions[vID &* 3 &+ 1] - centerOfMass.y
        let rZ = vPositions[vID &* 3 &+ 2] - centerOfMass.z
        var vX = vVelocities[vID &* 3 &+ 0]
        var vY = vVelocities[vID &* 3 &+ 1]
        var vZ = vVelocities[vID &* 3 &+ 2]
        
        // Apply the correction to linear velocity.
        vX -= linearDrift.x
        vY -= linearDrift.y
        vZ -= linearDrift.z
        
        // Apply the correction to angular velocity.
        let w = wDrift
        vX -= w.y * rZ - w.z * rY
        vY -= w.z * rX - w.x * rZ
        vZ -= w.x * rY - w.y * rX
        
        // Mask out the changes to anchor velocities.
        let mass = vMasses[vID]
        vX.replace(with: MM4FloatVector.zero, where: mass .== 0)
        vY.replace(with: MM4FloatVector.zero, where: mass .== 0)
        vZ.replace(with: MM4FloatVector.zero, where: mass .== 0)
        vKineticX.addProduct(mass, vX * vX)
        vKineticY.addProduct(mass, vY * vY)
        vKineticZ.addProduct(mass, vZ * vZ)
        vVelocities[vID &* 3 &+ 0] = vX
        vVelocities[vID &* 3 &+ 1] = vY
        vVelocities[vID &* 3 &+ 2] = vZ
      }
      correctedThermalKineticEnergy += MM4DoubleVector(vKineticX).sum()
      correctedThermalKineticEnergy += MM4DoubleVector(vKineticY).sum()
      correctedThermalKineticEnergy += MM4DoubleVector(vKineticZ).sum()
    }
    
    // Rescale thermal velocities and superimpose over bulk velocities.
    precondition(
      correctedThermalKineticEnergy > .leastNormalMagnitude,
      "Corrected thermal kinetic energy was too small to perform velocity rescaling.")
    
    let velocityScale = (
      Float(atoms.nonAnchorCount) * particleEnergy /
      Float(correctedThermalKineticEnergy)
    ).squareRoot()
    let w = constantAngularVelocity
    
    for vID in 0..<atoms.vectorCount {
      let rX = vPositions[vID &* 3 &+ 0] - centerOfMass.x
      let rY = vPositions[vID &* 3 &+ 1] - centerOfMass.y
      let rZ = vPositions[vID &* 3 &+ 2] - centerOfMass.z
      var vX = vVelocities[vID &* 3 &+ 0]
      var vY = vVelocities[vID &* 3 &+ 1]
      var vZ = vVelocities[vID &* 3 &+ 2]
      
      // Apply the correction to thermal velocity.
      vX *= velocityScale
      vY *= velocityScale
      vZ *= velocityScale
      
      // Apply the bulk angular velocity.
      vX += w.y * rZ - w.z * rY
      vY += w.z * rX - w.x * rZ
      vZ += w.x * rY - w.y * rX
      
      // Apply the bulk linear velocity.
      vX += constantLinearVelocity.x
      vY += constantLinearVelocity.y
      vZ += constantLinearVelocity.z
      
      // Mask out the changes to velocity of anchors.
      let mass = vMasses[vID]
      let anchorX = preservedVelocities[vID &* 3 &+ 0]
      let anchorY = preservedVelocities[vID &* 3 &+ 1]
      let anchorZ = preservedVelocities[vID &* 3 &+ 2]
      vX.replace(with: anchorX, where: mass .== 0)
      vY.replace(with: anchorY, where: mass .== 0)
      vZ.replace(with: anchorZ, where: mass .== 0)
      vVelocities[vID &* 3 &+ 0] = vX
      vVelocities[vID &* 3 &+ 1] = vY
      vVelocities[vID &* 3 &+ 2] = vZ
    }
  }
}

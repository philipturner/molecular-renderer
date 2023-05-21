//
//  AmbientOcclusion.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 5/15/23.
//

import Foundation
import GameplayKit

// Unfinished attempt to make a sampler optimized for 1 spp.
//
// Made using 'GPT-4/how-to-create-the-ao-sampler'
//
// Partially sourced from:
// https://github.com/microsoft/DirectX-Graphics-Samples/blob/master/Samples/Desktop/D3D12Raytracing/src/D3D12RaytracingRealTimeDenoisedAmbientOcclusion/RTAO/Sampler.h

class Sampler {
  typealias UnitSquareSample2D = SIMD2<Float>
  typealias HemisphereSample3D = SIMD3<Float>
  
  enum HemisphereDistribution {
    case uniform
    case cosine
  }
  
  private static let s_seed: UInt32 = 1729
  
  // TODO: Wrap this in a protocol and use generics to access the functions.
  private var getRandomJump: (() -> UInt32)?
  private var getRandomSetJump: (() -> UInt32)?
  private var getRandomFloat01: (() -> Float)?
  private var getRandomFloat01inclusive: (() -> Float)?
  
  private func generateSamples2D() {
    fatalError("Not implemented.")
  }
  
  private func randomFloat01_2D() -> UnitSquareSample2D {
    fatalError("Not implemented.")
  }
  
  private func getRandomNumber(min: UInt32, max: UInt32) -> UInt32 {
    fatalError("Not implemented.")
  }
  
  private var m_generatorURNG: GKMersenneTwisterRandomSource = .init()
  private var m_numSamples: UInt32 = 0
  private var m_numSampleSets: UInt32 = 0
  private var m_samples: [UnitSquareSample2D] = []
  private var m_hemisphereSamples: [HemisphereSample3D] = []
  
  private var m_index: UInt32 = 0
  private var m_shuffledIndices: [UInt32] = []
  private var m_jump: UInt32 = .max // invalid initial value
  private var m_setJump: UInt32 = .max // invalid initial value
  
  
}

extension Sampler {
  // Get a valid index from <0, m_numSampleSets * m_numSamples>.
  // The index increases by 1 on each call, but on a first
  // access of a next sample set, the:
  // - sample set is randomly picked
  // - sample set is indexed from a random starting index within a set.
  // In addition the order of indices is retrieved from shuffledIndices.
  func getSampleIndex() -> UInt32 {
    // Initialize sample and set jumps.
    if m_index % m_numSamples == 0 {
      // Pick a random index jump within a set.
      m_jump = getRandomJump!()
      
      // Pick a random set index jump.
      m_setJump = getRandomSetJump!() * m_numSamples
    }
    return m_setJump + m_shuffledIndices[Int((m_index + m_jump) % m_numSamples)]
  }
  
  // Resets the sampler with newly randomly generated samples
  func reset(
    numSamples: UInt32,
    numSampleSets: UInt32,
    hemisphereDistribution: HemisphereDistribution
  ) {
    m_index = 0
    m_numSamples = numSamples
    m_numSampleSets = numSampleSets
    m_samples = Array(
      repeating: .init(repeating: .greatestFiniteMagnitude),
      count: Int(m_numSamples * m_numSampleSets))
    m_shuffledIndices = Array(
      repeating: 0,
      count: Int(m_numSamples * m_numSampleSets))
    m_hemisphereSamples = Array(
      repeating: .init(repeating: .greatestFiniteMagnitude),
      count: Int(m_numSamples * m_numSampleSets))
    
    // Reset generator and initialize distributions.
    do {
      // Initialize to the same seed for determinism.
      m_generatorURNG = .init(seed: UInt64(Sampler.s_seed))
      
      let jumpDistribution = GKRandomDistribution(
        randomSource: m_generatorURNG, lowestValue: 0,
        highestValue: Int(m_numSamples - 1))
      let jumpSetDistribution = GKRandomDistribution(
        randomSource: m_generatorURNG, lowestValue: 0,
        highestValue: Int(m_numSampleSets - 1))
      let unitSquareDistribution = GKRandomDistribution(
        randomSource: m_generatorURNG, lowestValue: 0,
        highestValue: 1 << 20 - 1) // divide by 1 << 20
      let unitSquareDistributionInclusive = GKRandomDistribution(
        randomSource: m_generatorURNG, lowestValue: 0,
        highestValue: 1 << 20) // divide by 1 << 20
      
      getRandomJump = { UInt32(jumpDistribution.nextInt()) }
      getRandomSetJump = { UInt32(jumpSetDistribution.nextInt()) }
      getRandomFloat01 = {
        Float(unitSquareDistribution.nextInt()) / Float(1 << 20)
      }
      getRandomFloat01inclusive = {
        Float(unitSquareDistributionInclusive.nextUniform()) / Float(1 << 20)
      }
    }
    
    // Generate random samples.
    do {
      generateSamples2D()
      
      switch hemisphereDistribution {
      case .uniform:
        initializeHemisphereSamples(cosDensityPower: 0.0)
      case .cosine:
        initializeHemisphereSamples(cosDensityPower: 1.0)
      }
      
      for i in 0..<m_numSampleSets {
        let first = Int(i * m_numSamples)
        let last = first + Int(m_numSamples)
        m_shuffledIndices[first..<last].iota(0)
        m_shuffledIndices[first..<last].shuffle()
      }
    }
  }

  // Initialize samples on a 3D hemisphere from 2D unit square samples
  // cosDensityPower - cosine density power {0, 1, ...}. 0:uniform, 1:cosine,...
  func initializeHemisphereSamples(cosDensityPower: Float) {
    for i in 0..<m_samples.count {
      // Compute azimuth (phi) and polar angle (theta)
      /*
       let phi = Float.pi * 2 * m_samples[i].x
       let theta = acos(
         pow((1.0 - m_samples[i].y), 1.0 / (cosDensityPower + 1)))
       
       // Convert the polar angles to a 3D point in local orthonormal
       // basis with orthogonal unit vectors along x, y, z.
       m_hemisphereSamples[i].x = sin(theta) * cos(phi)
       m_hemisphereSamples[i].y = sin(theta) * sin(phi)
       m_hemisphereSamples[i].z = cos(theta)
       */
      // Optimized version using trigonometry equations.
      let cosTheta = pow((1.0 - m_samples[i].y), 1.0 / (cosDensityPower + 1))
      let sinTheta = sqrt(1.0 - cosTheta * cosTheta)
      m_hemisphereSamples[i].x = sinTheta * cos(Float.pi * 2 * m_samples[i].x)
      m_hemisphereSamples[i].y = sinTheta * sin(Float.pi * 2 * m_samples[i].x)
      m_hemisphereSamples[i].z = cosTheta
      
    }
  }
}

extension MutableCollection where Element: Numeric {
    mutating func iota(_ value: Element) {
        var val = value
        for i in self.indices {
            self[i] = val
            val += 1
        }
    }
}

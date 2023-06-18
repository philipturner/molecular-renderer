//
//  PlayerState.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/18/23.
//

import Foundation
import simd

// Stores the azimuth's multiple of 2 * pi separately from the phase. This
// preserves the dynamic range without interfering with the averaging process.
// Limits the zenith to a range between 0 and pi radians to prevent flipping.
struct Orientation {
  // All angles are stored in units of revolutions.
  private var azimuthQuotient: Int
  private var azimuthRemainder: Double
  private var zenith: Double // clamped to (0, pi)
  
  // Enter azimuth and zenith in revolutions, not radians.
  init(azimuth: Double, zenith: Double) {
    self.azimuthQuotient = 0
    self.azimuthRemainder = azimuth
    self.zenith = zenith
    
    // The inputs might not be within the desired range.
    self.normalize()
  }
  
  // Average several angles, while preserving the quotient.
  init(averaging orientations: [Orientation]) {
    self.azimuthQuotient = 0
    self.azimuthRemainder = 0
    self.zenith = 0
    
    for orientation in orientations {
      azimuthQuotient += orientation.azimuthQuotient
      azimuthRemainder += orientation.azimuthRemainder
      zenith += orientation.zenith
    }
    
    // Re-normalizing here won't fix the loss of mantissa information, but it
    // will erroneously clamp the sum of zeniths.
    let sizeReciprocal = recip(Double(orientations.count))
    var temp_azimuth = Double(self.azimuthQuotient)
    temp_azimuth *= sizeReciprocal
    self.azimuthRemainder *= sizeReciprocal
    self.zenith *= sizeReciprocal
    
    let quotient = temp_azimuth.rounded(.down)
    let remainder = temp_azimuth - quotient
    self.azimuthQuotient = Int(quotient)
    self.azimuthRemainder += remainder
    
    // Re-normalize after averaging the angles.
    self.normalize()
  }
  
  mutating func normalize() {
    let floor = azimuthRemainder.rounded(.down)
    self.azimuthQuotient += Int(floor)
    self.azimuthRemainder = azimuthRemainder - floor
    self.zenith = simd_clamp(zenith, 0, 0.5)
  }
  
  mutating func add(azimuth: Double, zenith: Double) {
    self.azimuthRemainder += azimuth
    self.zenith += zenith
    
    // Re-normalize after changing the angles.
    self.normalize()
  }
  
  var phase: (azimuth: Double, zenith: Double) {
    return (self.azimuthRemainder, self.zenith)
  }
}

// Takes the average of the last N positions, to smooth out sudden jolts caused
// by imperfect sampling. This decreases nausea and perceived stuttering. The
// motion lag is (N - 1)/2 and the noise scales with rsqrt(N). However, the
// reference system only needs 2 samples to smooth out most noise.
struct RingBuffer{
  private var history: [Orientation]
  private var index: Int = 0
  var last: Orientation
  
  init(repeating value: Orientation, count: Int) {
    self.history = .init(repeating: value, count: count)
    self.last = value
  }
  
  mutating func store(_ value: Orientation) {
    defer {
      index = (index + 1) % history.count
    }
    
    self.history[index] = value
    self.last = value
  }
  
  func load() -> Orientation {
    Orientation(averaging: history)
  }
}

struct PlayerState {
  static let historyLength: Int = 3
  
  // Player position in nanometers.
  var position: SIMD3<Float> = SIMD3(repeating: 0)
  
  // The orientation of the camera or the player in revolutions
  var orientationHistory: RingBuffer = .init(
    repeating: Orientation(azimuth: 0, zenith: 0.25), count: historyLength)
  
  // Use azimuth * zenith to get the correct orientation from Minecraft.
  var rotations: (azimuth: simd_float3x3, zenith: simd_float3x3) {
    // Assume that the world space axes are x, y, z and the camera space axes
    // are u, v, w
    // Assume that the azimuth angle is a and the zenith angle is b
    // Assume that the ray direction in world space is r = (rx, ry, rz) and in
    // camera space is s = (su, sv, sw)

    // The transformation matrix can be obtained by multiplying two rotation
    // matrices: one for azimuth and one for zenith
    // The azimuth rotation matrix rotates the world space axes around the
    // y-axis by -a radians
    // The zenith rotation matrix rotates the camera space axes around the
    // u-axis by -b radians
    
    var (azimuth, zenith) = orientationHistory.load().phase
    azimuth = -azimuth
    zenith = zenith - 0.25
    
    let x: SIMD2<Double> = .init(azimuth, zenith) * 2
    var sinvals: SIMD2<Double> = .zero
    var cosvals: SIMD2<Double> = .zero
    _simd_sincospi_d2(x, &sinvals, &cosvals)
    
    let sina = Float(sinvals[0])
    let cosa = Float(cosvals[0])
    let sinb = Float(sinvals[1])
    let cosb = Float(cosvals[1])
    
    // The azimuth rotation matrix is:
    let M_a = simd_float3x3(SIMD3(cosa, 0, sina),
                            SIMD3(0, 1, 0),
                            SIMD3(-sina, 0, cosa))
      .transpose // simd and Metal use the column-major format

    // The zenith rotation matrix is:
    let M_b = simd_float3x3(SIMD3(1, 0, 0),
                            SIMD3(0, cosb, -sinb),
                            SIMD3(0, sinb, cosb))
      .transpose // simd and Metal use the column-major format
    
    return (azimuth: M_a, zenith: M_b)
  }
  
  // FOV dilation due to sprinting.
  func fovDegrees(progress: Float) -> Float {
    return simd_mix(90, 90 * 1.20, progress)
  }
}

// Keeps track of how long you have been sprinting for. Used to determine how to
// dilate the FOV.
struct SprintingHistory {
  // Each sample gets retained for a fixed period of time, determined using the
  // timestamp.
  private var samples: [(timestamp: Double, sprinting: Bool)] = []
  
  private static let timeout: Double = 0.1
  
  private var currentTimestamp: Double = -.infinity
  
  mutating func update(timestamp: Double, sprinting: Bool) {
    currentTimestamp = timestamp
    if samples.count > 0 {
      while samples.first!.timestamp < currentTimestamp - Self.timeout {
        samples.removeFirst()
        if samples.count == 0 {
          break
        }
      }
    }
    samples.append((timestamp, sprinting))
  }
  
  private func rawProgress() -> Float {
    if samples.count == 0 {
      return 0
    }
    var trueSamples: Int = 0
    for sample in samples where sample.sprinting {
      trueSamples += 1
    }
    var t = Float(trueSamples) / Float(samples.count)
    
    // This heuristic might fail if the framerate is too jumpy.
    var amountFilled = currentTimestamp - samples.first!.timestamp
    amountFilled /= Self.timeout
    
    let fillCutoff: Double = 0.5
    if amountFilled < fillCutoff {
      t *= Float(amountFilled / fillCutoff)
    }
    return t
  }

  // Progress between the standard FOV and the target FOV.
  //
  // TODO: Exactly how fast does the transition between FOVs last in Minecraft?
  // I know it's a smooth polynomial; the exact equation doesn't matter. Here's
  // the Metal Standard Library's `smoothstep` function:
  //
  // float smoothstep(float edge0, float edge1, float x)
  // {
  //   float t = clamp((x - edge0) / (edge1 - edge0), float(0), float(1));
  //   return t * t * (float(3) - float(2) * t);
  // }
  func smoothedProgress() -> Float {
    func smoothstep(edge0: Float, edge1: Float, x: Float) -> Float {
      let t = simd_clamp((x - edge0) / (edge1 - edge0), Float(0), Float(1))
      return t * t * (Float(3) - Float(2) * t)
    }
    return 2 * smoothstep(edge0: 0, edge1: 1, x: rawProgress() / 2)
  }
}

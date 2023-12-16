//
//  InputEvents.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/15/23.
//

import Atomics
import AppKit
import KeyCodes
import MolecularRenderer
import simd

// Stores the events that occurred this frame, performs certain actions based on
// each event, then clears the list of events when necessary.
class EventTracker {
  // State of the player in 3D.
  var playerState = PlayerState()
  
  // The base speed (in nm/ps) for walking, scaled by 5x when sprinting.
  // This variable can be changed to enable quicker movement in larger scenes.
  var walkingSpeed: Float = 1
  
  // The sensitivity of the mouse movement
  //
  // I measured my trackpad as (816, 428). In Minecraft, two sweeps up the
  // trackpad's Y direction rotated exactly 180 degrees. The settings were also
  // at "mouse sensitivity = 100%". You have to drag slowly, because mouse
  // acceleration can make it rotate more.
  var sensitivity: CGFloat = Double(0.5) / 2 / 428
  
  // The first frame sometimes contains a sudden, buggy jump to an astronomical
  // mouse position.
  var remainingQuarantineFrames: Int = 2
  
  // Time to apply to the timeout counter for motion keys.
  var lastTime: Double?
  
  // W, A, S, D, Spacebar, and Shift are for moving.
  // P and R are for playing/restarting the animation.
  var keyCodes: [KeyboardHIDUsage]
  var keyboardW: Key
  var keyboardA: Key
  var keyboardS: Key
  var keyboardD: Key
  var keyboardSpacebar: Key
  var keyboardShift: Key
  var keyboardP: Key
  var keyboardR: Key
  
  subscript(keyCode: KeyboardHIDUsage) -> Key {
    get {
      switch keyCode {
      case .keyboardW: return keyboardW
      case .keyboardA: return keyboardA
      case .keyboardS: return keyboardS
      case .keyboardD: return keyboardD
      case .keyboardSpacebar: return keyboardSpacebar
      case .keyboardLeftShift: return keyboardShift
      case .keyboardP: return keyboardP
      case .keyboardR: return keyboardR
      default: fatalError("Invalid key code.")
      }
    }
    set {
      switch keyCode {
      case .keyboardW: keyboardW = newValue
      case .keyboardA: keyboardA = newValue
      case .keyboardS: keyboardS = newValue
      case .keyboardD: keyboardD = newValue
      case .keyboardSpacebar: keyboardSpacebar = newValue
      case .keyboardLeftShift: keyboardShift = newValue
      case .keyboardP: keyboardP = newValue
      case .keyboardR: keyboardR = newValue
      default: fatalError("Invalid key code.")
      }
    }
  }
  
  // Each key has its own sprinting history for speed, but the FOV has its own
  // history. If any key is sprinting, the FOV history logs a sample.
  var fovHistory: SprintingHistory = .init()
  
  // Don't move the player if the window is in the background. Often, the
  // player will move uncontrollably in one direction, even through you aren't
  // pressing any key.
  var windowInForeground: ManagedAtomic<Bool> = ManagedAtomic(true)
  var mouseInWindow: ManagedAtomic<Bool> = ManagedAtomic(true)
  
  // When the crosshair is inactive, we disallow WASD and the mouse. We don't
  // want the user to mess with a predefined player position accidentally.
  var crosshairActive: ManagedAtomic<Bool> = ManagedAtomic(false)
  var hideCursorCount: Int = 0
  
  // Buffer up the movements while waiting for the other thread to respond. This
  // should be auto-cleared if it is not used.
  var accumulatedMouseDeltaX: ManagedAtomic<UInt64> = ManagedAtomic(0)
  var accumulatedMouseDeltaY: ManagedAtomic<UInt64> = ManagedAtomic(0)
  
  init() {
    keyCodes = [
      .keyboardW,
      .keyboardS,
      .keyboardA,
      .keyboardD,
      .keyboardLeftShift,
      .keyboardSpacebar,
      .keyboardP,
      .keyboardR,
    ]
    keyboardW = Key([0, 0, -1], opposite: .keyboardS)
    keyboardS = Key([0, 0, +1], opposite: .keyboardW)
    keyboardA = Key([-1, 0, 0], opposite: .keyboardD)
    keyboardD = Key([+1, 0, 0], opposite: .keyboardA)
    keyboardShift = Key([0, -1, 0], opposite: .keyboardSpacebar)
    keyboardSpacebar = Key([0, +1, 0], opposite: .keyboardLeftShift)
    keyboardP = Key(nil, opposite: .keyboardR)
    keyboardR = Key(nil, opposite: .keyboardP)
    
    NSEvent.addLocalMonitorForEvents(matching: .mouseExited) { event in
      self.mouseInWindow.store(false, ordering: .relaxed)
      return event
    }
    
    NSEvent.addLocalMonitorForEvents(matching: .mouseEntered) { event in
      self.mouseInWindow.store(true, ordering: .relaxed)
      return event
    }
    
    NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
      for (atomic, delta) in [(self.accumulatedMouseDeltaX, event.deltaX),
                              (self.accumulatedMouseDeltaY, event.deltaY)] {
        let maxTries = 10
        var numTries = 0
        var original = atomic.load(ordering: .sequentiallyConsistent)
        
        while numTries < maxTries {
          let next = (Double(bitPattern: original) + delta).bitPattern
          var exchanged: Bool
          (exchanged, original) = atomic.compareExchange(
            expected: original, desired: next,
            ordering: .sequentiallyConsistent)
          
          if exchanged {
            break
          } else {
            numTries += 1
          }
        }
        if numTries >= maxTries {
          print("Failed to update mouse position: too many tries.")
        }
      }
      return event
    }
  }
  
  // Check that the user is looking at the application.
  //
  // If not, do not accept keyboard input. Doing so leads to a bug where the
  // keyboard is disabled, even though the crosshair is active.
  var shouldAcceptInput: Bool {
    var accept = windowInForeground.load(ordering: .relaxed)
    accept = accept && mouseInWindow.load(ordering: .relaxed)
    return accept
  }
  
  func update(time: MRTimeContext) {
    // Proceed if the user is not in the game menu (analogy from Minecraft).
    if shouldAcceptInput, crosshairActive.load(ordering: .relaxed) {
      // Update keyboard first.
      self.updatePosition(time: time)
      
      // Update mouse second, so it can respond to the ESC key immediately.
      self.updateCamera()
    } else {
      // Do not move the player right now.
      for keyCode in keyCodes {
        self[keyCode].pressed = false
      }
      
      // Sprinting FOV should decrease even when the user is inactive.
      fovHistory.update(time: time, sprinting: false)
    }
    
    // Prevent previous mouse events from affecting future frames.
    self.accumulatedMouseDelta = SIMD2(repeating: 0)
  }
}

extension EventTracker {
  func updatePosition(time: MRTimeContext) {
    // In Minecraft, WASD only affects horizontal position, even when flying.
    let azimuth = playerState.rotations.azimuth
    
    var anyKeySprinting = false
    for keyCode in keyCodes {
      let oldValue = self[keyCode]
      guard let cameraSpaceDirection = oldValue.motionDirection else {
        continue
      }
      
      let same = oldValue.pressed
      let opposite = self[oldValue.opposite].pressed
      var newState = oldValue.state!
      newState.update(time: time, pressed: (same, opposite))
      self[keyCode].state = newState
      
      if newState.running {
        if newState.sprinting {
          anyKeySprinting = true
        }
        
        let slow = walkingSpeed
        let fast = walkingSpeed * 5
        let speed = cross_platform_mix(slow, fast, newState.history.progress)
        let delta = speed * Float(time.relative.seconds)
        let worldSpaceDirection = azimuth * cameraSpaceDirection
        playerState.position += worldSpaceDirection * delta
      }
    }
    fovHistory.update(time: time, sprinting: anyKeySprinting)
  }
}

// Handle mouse events.
extension EventTracker {
  // Reference:
  // https://stackoverflow.com/questions/50357135/swift-keep-mouse-pointer-from-leaving-window
  var accumulatedMouseDelta: SIMD2<Double> {
    get {
      return SIMD2(
        .init(bitPattern: accumulatedMouseDeltaX.load(
          ordering: .sequentiallyConsistent)),
        .init(bitPattern: accumulatedMouseDeltaY.load(
          ordering: .sequentiallyConsistent)))
    }
    set {
      accumulatedMouseDeltaX.store(
        newValue.x.bitPattern, ordering: .sequentiallyConsistent)
      accumulatedMouseDeltaY.store(
        newValue.y.bitPattern, ordering: .sequentiallyConsistent)
    }
  }
  
  func updateCamera() {
    // Interpret the accumulated mouse delta as the translation.
    let translation = self.accumulatedMouseDelta
    if translation != .zero {
      if remainingQuarantineFrames > 0 {
        remainingQuarantineFrames -= 1
        return
      }
    }
    
    // Update the azimuth angle by adding the horizontal translation
    // multiplied by the sensitivity
    let azimuthDelta = translation.x * sensitivity

    // Update the zenith angle by subtracting the vertical translation
    // multiplied by the sensitivity
    let zenithDelta = translation.y * -sensitivity
    
    // Fetch the current orientation, then add to it.
    var orientation = playerState.orientationHistory.last
    orientation.add(azimuth: azimuthDelta, zenith: zenithDelta)
    playerState.orientationHistory.store(orientation)
  }
}


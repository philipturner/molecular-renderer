//
//  MotionKey.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/9/23.
//

import AppKit
import Atomics
import MolecularRenderer
import KeyCodes

// === Speeds in Minecraft ===
//
// We are emulating flying, where sprinting exactly doubles the speed.
//
//                   Walking | 4.30 m/s <- exact value is 4.32 m/s
//   Walking while sprinting | 5.56 m/s
//                    Flying | 10.7 m/s <- exact value is 10.8 m/s
//    Flying while sprinting | 21.1 m/s
//
// === FOV in Minecraft ===
//
// Typical FOV is 70 degrees
// - Often quoted increase is +20 absolute (+28.57%)
// - That is "way too high"
// - +10% increase while flying is less than for sprinting
// - Use +20% as the FOV change
//
// However, we're not going from:
//   (walking no sprint) -> (walking sprint)
// Or:
//   (walking no sprint) -> (flying sprint)
// We're going from:
//   (flying no sprint) -> (flying sprint)
//
// Stick with the initial estimate of 10%, like we're going up a hierarchy:
//   (walking no sprint) +0% (x1.00)
//     (flying no sprint) +10% (x1.10)
//      (walking sprint) +10-20% (x1.10-1.20)
//       (flying sprint)    ?????? (x1.20-1.21)
//

struct MotionState {
  var running: Bool = false
  var sprinting: Bool = false
  
  // This number keeps decreasing to negative infinity each frame. Whenever
  // the key is pressed, it is manually reset to the timeout. This allows it
  // to detect a double-press for sprinting.
  var timer: Double = -1
  
  var history: SprintingHistory = .init()
  
  mutating func update(
    time: MRTimeContext, pressed: (same: Bool, opposite: Bool)
  ) {
    timer -= time.relative.seconds
    
    if running && !pressed.same {
      if sprinting {
        running = false
        sprinting = false
      } else {
        running = false
      }
    } else if !running && pressed.same {
      if sprinting {
        fatalError("This should never happen.")
      } else {
        running = true
        sprinting = timer > 0
        
        if timer > 0 {
          timer = -1
        } else {
          timer = 0.3
        }
      }
    }
    
    if pressed.opposite {
      sprinting = false
      timer = -1
    }
    
    history.update(time: time, sprinting: sprinting)
  }
}

struct Key {
  // Use atomics to bypass the crash when the main thread accesses this.
  private var _pressed: ManagedAtomic<Bool> = ManagedAtomic(false)
  var pressed: Bool {
    get { _pressed.load(ordering: .sequentiallyConsistent) }
    set { _pressed.store(newValue, ordering: .sequentiallyConsistent) }
  }
  
  // The paired key. If you are currently sprinting, you should suppress the
  // sprinting on this key.
  var opposite: KeyboardHIDUsage
  
  // Direction the key moves the player, in camera space.
  var motionDirection: SIMD3<Float>?
  
  // The state affecting how the user moves over time.
  var state: MotionState?
  
  init(_ motionDirection: SIMD3<Float>?, opposite: KeyboardHIDUsage) {
    self.opposite = opposite
    
    if let motionDirection {
      self.motionDirection = motionDirection
      self.state = MotionState()
    }
  }
}

// Handle keyboard events.
extension Coordinator {
  override func keyDown(with event: NSEvent) {
    super.keyDown(with: event)
    let keyCode = event.key!.keyCode
    
    // Key down toggles the value, key up does nothing.
    if keyCode == .keyboardEscape {
      showCrosshair = !showCrosshair
      eventTracker.crosshairActive.store(showCrosshair, ordering: .relaxed)
      
      if showCrosshair {
        if eventTracker.shouldAcceptInput {
          hideCursor()
        }
      } else {
        // Always opt on the side of freeing the cursor.
        showCursor()
      }
    }
    
    guard eventTracker.keyCodes.contains(keyCode) else { return }
    if eventTracker.shouldAcceptInput {
      eventTracker[keyCode].pressed = true
    }
  }
  
  override func keyUp(with event: NSEvent) {
    super.keyUp(with: event)
    let keyCode = event.key!.keyCode
    if keyCode == .keyboardEscape { return }
    
    guard eventTracker.keyCodes.contains(keyCode) else { return }
    if eventTracker.shouldAcceptInput {
      eventTracker[keyCode].pressed = false
    }
  }
  
  override func flagsChanged(with event: NSEvent) {
    super.flagsChanged(with: event)
    guard eventTracker.shouldAcceptInput else { return }

    // There is no way to detect which shift is left or right, but there is
    // also no enum case for a direction-independent shift. So I name all shifts
    // as left shifts and leave it at that.
    let flags = event.modifierFlags.deviceIndependentOnly
    let pressed = flags.contains(.shift)
    eventTracker[.keyboardLeftShift].pressed = pressed
  }
}

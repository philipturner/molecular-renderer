//
//  InputEvents.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/15/23.
//

import Atomics
import AppKit
import KeyCodes
import simd

struct PlayerState {
  // Player position in nanometers.
  var position: SIMD3<Float> = SIMD3(repeating: 0)
  
  // The azimuth angle of the camera or the player in radians
  var azimuthAngle: CGFloat = 0

  // The zenith angle of the camera or the player in radians
  var zenithAngle: CGFloat = .pi / 2
  
  func makeRotationMatrix() -> simd_float3x3 {
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
    
    let a = Float(azimuthAngle)
    let b = Float.pi / 2 - Float(zenithAngle)

    // The azimuth rotation matrix is:
    let M_a = simd_float3x3(SIMD3(cos(-a), 0, sin(-a)),
                            SIMD3(0, 1, 0),
                            SIMD3(-sin(-a), 0, cos(-a)))
      .transpose // simd and Metal use the column-major format

    // The zenith rotation matrix is:
    let M_b = simd_float3x3(SIMD3(1, 0, 0),
                            SIMD3(0, cos(-b), -sin(-b)),
                            SIMD3(0, sin(-b), cos(-b)))
      .transpose // simd and Metal use the column-major format
    
//    // The transformation matrix is:
//    return M_b * M_a
    
    // Switch the order of rotation, and you get the correct rotation from
    // Minecraft.
    return M_a * M_b
  }
}

// Stores the events that occurred this frame, performs certain actions based on
// each event, then clears the list of events when necessary.
class EventTracker {
  // State of the player in 3D.
  var playerState = PlayerState()
  
  // The sensitivity of the mouse movement
  // Measured my trackpad as (816, 428). In Minecraft, two sweeps up the
  // trackpad's Y direction rotated exactly 180 degrees. The settings were also
  // at "mouse sensitivity = 100%".
  var sensitivity: CGFloat = Double.pi / 2 / 428
  
  // TODO: Smooth out the very shaky movements - they might be causing a little
  // bit of nausea. In Minecraft, it definitely feels delayed and/or smoothed,
  // although it always arrives at the same precise position.
  //
  // This might have been fixed by decreasing the sensitivity (0.01 -> 0.0036).
  // But leave the notice here; nausea is a very bad user experience problem.
  
  // Use atomics to bypass the crash when the main thread tries to access this.
  var keyboardWPressed: ManagedAtomic<Bool> = .init(false)
  var keyboardAPressed: ManagedAtomic<Bool> = .init(false)
  var keyboardSPressed: ManagedAtomic<Bool> = .init(false)
  var keyboardDPressed: ManagedAtomic<Bool> = .init(false)
  
  // TODO: Minecraft-like sprinting or elytra controls, physics-based
  // collisions with the nanostructure
  var keyboardSpacebarPressed: ManagedAtomic<Bool> = .init(false)
  var keyboardShiftPressed: ManagedAtomic<Bool> = .init(false)
  
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
  
  func update(frameDelta: Int) {
    // Check that the user is looking at the application.
    // Proceed if the user is not in the game menu (analogy from Minecraft).
    if windowInForeground.load(ordering: .relaxed),
       mouseInWindow.load(ordering: .relaxed),
       read(key: .keyboardEscape) == false {
      // Update keyboard first.
      self.updateKeyboard(frameDelta: frameDelta)
      
      // Update mouse second, so it can respond to the ESC key immediately.
      self.updateMouse()
    } else {
      // Do not move the player right now.
    }
    
    // Prevent previous mouse events from affecting future frames.
    self.accumulatedMouseDelta = SIMD2(repeating: 0)
  }
  
  // Perform any necessary cleanup, then close the app.
  func closeApp(coordinator: Coordinator) {
    exit(0)
  }
}

extension EventTracker {
  func change(key: KeyboardHIDUsage, value: Bool) {
    switch key {
    case .keyboardW:
      keyboardWPressed.store(value, ordering: .relaxed)
    case .keyboardA:
      keyboardAPressed.store(value, ordering: .relaxed)
    case .keyboardS:
      keyboardSPressed.store(value, ordering: .relaxed)
    case .keyboardD:
      keyboardDPressed.store(value, ordering: .relaxed)
    case .keyboardSpacebar:
      keyboardSpacebarPressed.store(value, ordering: .relaxed)
    case .keyboardLeftShift:
      keyboardShiftPressed.store(value, ordering: .relaxed)
    case .keyboardEscape:
      // Key down toggles the value, key up does nothing.
      _ = crosshairActive.loadThenLogicalXor(with: value, ordering: .relaxed)
    default:
      break
    }
  }
  
  func read(key: KeyboardHIDUsage) -> Bool {
    switch key {
    case .keyboardW:
      return keyboardWPressed.load(ordering: .relaxed)
    case .keyboardA:
      return keyboardAPressed.load(ordering: .relaxed)
    case .keyboardS:
      return keyboardSPressed.load(ordering: .relaxed)
    case .keyboardD:
      return keyboardDPressed.load(ordering: .relaxed)
    case .keyboardSpacebar:
      return keyboardSpacebarPressed.load(ordering: .relaxed)
    case .keyboardLeftShift:
      return keyboardShiftPressed.load(ordering: .relaxed)
    case .keyboardEscape:
      // `true` means the crosshair is NOT active. This is analogous to
      // Minecraft, where ESC opens the game menu.
      return !crosshairActive.load(ordering: .relaxed)
    default:
      fatalError("Unsupported key \(key)")
    }
  }
}

// Handle keyboard events.
extension Coordinator {
  // A method to handle key events
  override func keyDown(with event: NSEvent) {
    super.keyDown(with: event)
    
    // Get the event type
    let type = event.type
    
    // Check if the event type is NSKeyDown
    if type == .keyDown {
      // Get the key code of the event
      let keyCode = event.key!.keyCode
      
      // Set the corresponding value in the keys pressed dictionary to true
      eventTracker.change(key: keyCode, value: true)
    }
  }
  
  // A method to handle key events
  override func keyUp(with event: NSEvent) {
    super.keyUp(with: event)
    
    // Get the event type
    let type = event.type
    
    // Check if the event type is NSKeyUp
    if type == .keyUp {
      // Get the key code of the event
      let keyCode = event.key!.keyCode
      
      // Set the corresponding value in the keys pressed dictionary to false
      eventTracker.change(key: keyCode, value: false)
    }
  }
  
  // A method to handle modifier flags change events
  override func flagsChanged(with event: NSEvent) {
    super.flagsChanged(with: event)

    // Get the modifier flags of the event
    let flags = event.modifierFlags.deviceIndependentOnly
    
    // Check if the shift flag is set and if it is left shift
    //
    // There is no way to detect which shift is left or right, but there is
    // also no enum case for a direction-independent shift. So I name all shifts
    // as left shifts and leave it at that.
    if flags.contains(.shift) {
      // Set the value for keyboardLeftShift in the keys pressed dictionary to true
      eventTracker.change(key: .keyboardLeftShift, value: true)
    } else {
      // Set the value for keyboardLeftShift in the keys pressed dictionary to false
      eventTracker.change(key: .keyboardLeftShift, value: false)
    }
  }
}

extension EventTracker {
  func updateKeyboard(frameDelta: Int) {
    var pressedKeys: [String] = []
    
    // Define a constant for the movement speed
    // 1.0 nanometers per second
    let speed: Float = 1.0
    let positionDelta = speed * Float(frameDelta) / 120
    
    // In Minecraft, WASD only affects horizontal position, even when flying.
    let a = Float(playerState.azimuthAngle)
    let M_a = simd_float3x3(SIMD3(cos(-a), 0, sin(-a)),
                            SIMD3(0, 1, 0),
                            SIMD3(-sin(-a), 0, cos(-a)))
      .transpose // simd and Metal use the column-major format
    let basisVectorX = M_a * SIMD3(1, 0, 0)
    let basisVectorZ = M_a * SIMD3(0, 0, 1)
    
    // Check if W is pressed and move forward along the z-axis
    if read(key: .keyboardW) == true {
      pressedKeys.append("W")
      playerState.position -= basisVectorZ * positionDelta
    }
    
    // Check if S is pressed and move backward along the z-axis
    if read(key: .keyboardS) == true {
      pressedKeys.append("S")
      playerState.position += basisVectorZ * positionDelta
    }
    
    // Check if A is pressed and move left along the x-axis
    if read(key: .keyboardA) == true {
      pressedKeys.append("A")
      playerState.position -= basisVectorX * positionDelta
    }
    
    // Check if D is pressed and move right along the x-axis
    if read(key: .keyboardD) == true {
      pressedKeys.append("D")
      playerState.position += basisVectorX * positionDelta
    }
    
    // Check if spacebar is pressed and move up along the y-axis
    if read(key: .keyboardSpacebar) == true {
      pressedKeys.append("SPACE")
      playerState.position.y += positionDelta
    }
    
    // Check if left shift is pressed and move down along the y-axis
    if read(key: .keyboardLeftShift) == true {
      pressedKeys.append("LSHIFT")
      playerState.position.y -= positionDelta
    }
    
//    if !pressedKeys.isEmpty {
//      let message = String(pressedKeys.joined(separator: " "))
//      print(message)
//    }
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
  
  func updateMouse() {
    // Interpret the accumulated mouse delta as the translation.
    let translation = self.accumulatedMouseDelta
    
    // Update the azimuth angle by adding the horizontal translation
    // multiplied by the sensitivity
    playerState.azimuthAngle += translation.x * sensitivity

    // Update the zenith angle by subtracting the vertical translation
    // multiplied by the sensitivity
    playerState.zenithAngle -= translation.y * sensitivity

    // Limit the zenith angle to a range between 0 and pi radians to prevent
    // flipping
    playerState.zenithAngle = max(0, min(.pi, playerState.zenithAngle))
    
    print("Angles: \(playerState.azimuthAngle / .pi), \(playerState.zenithAngle / .pi), Translation: \(translation)")
  }
}

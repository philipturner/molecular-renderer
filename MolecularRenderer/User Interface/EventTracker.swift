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


// Stores the events that occurred this frame, performs certain actions based on
// each event, then clears the list of events when necessary.
class EventTracker {
  // State of the player in 3D.
  var playerState = PlayerState()
  
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
  
  // TODO: Incorporate sprinting while flying, ease in/out the FOV.
  
  // Use atomics to bypass the crash when the main thread tries to access this.
  var keyboardWPressed: ManagedAtomic<Bool> = .init(false)
  var keyboardAPressed: ManagedAtomic<Bool> = .init(false)
  var keyboardSPressed: ManagedAtomic<Bool> = .init(false)
  var keyboardDPressed: ManagedAtomic<Bool> = .init(false)
  var keyboardSpacebarPressed: ManagedAtomic<Bool> = .init(false)
  var keyboardShiftPressed: ManagedAtomic<Bool> = .init(false)
  
  // Don't move the player if the window is in the background. Often, the
  // player will move uncontrollably in one direction, even through you aren't
  // pressing any key.
  var windowInForeground: ManagedAtomic<Bool> = ManagedAtomic(true)
  var mouseInWindow: ManagedAtomic<Bool> = ManagedAtomic(true)
  
  // When the crosshair is inactive, we disallow WASD and the mouse. We don't
  // want the user to mess with a predefined player position accidentally.
  var crosshairActive: ManagedAtomic<Bool> = ManagedAtomic(
    Coordinator.initiallyShowCrosshair)
  var hideCursorCount: Int = 0
  
  // Buffer up the movements while waiting for the other thread to respond. This
  // should be auto-cleared if it is not used.
  var accumulatedMouseDeltaX: ManagedAtomic<UInt64> = ManagedAtomic(0)
  var accumulatedMouseDeltaY: ManagedAtomic<UInt64> = ManagedAtomic(0)
  
  init() {
    // TODO: Find another workaround. Since we pinned the mouse inside the
    // window, and we can't receive key up events anymore, there's now a glitch
    // where the player moves in one direction after you let go. This occurs
    // when pressing F3.
    
    NSEvent.addLocalMonitorForEvents(matching: .mouseExited) { event in
      print("Mouse exited window.")
      self.mouseInWindow.store(false, ordering: .relaxed)
      return event
    }
    
    NSEvent.addLocalMonitorForEvents(matching: .mouseEntered) { event in
      print("Mouse entered window.")
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
  var shouldAcceptInput: Bool {
    var accept = windowInForeground.load(ordering: .relaxed)
    accept = accept && mouseInWindow.load(ordering: .relaxed)
    return accept
  }
  
  func update(frameDelta: Int) {
    // Proceed if the user is not in the game menu (analogy from Minecraft).
    if shouldAcceptInput, read(key: .keyboardEscape) == false {
      // Update keyboard first.
      self.updateKeyboard(frameDelta: frameDelta)
      
      // Update mouse second, so it can respond to the ESC key immediately.
      self.updateMouse()
    } else {
      // Do not move the player right now.
      self.change(key: .keyboardW, value: false)
      self.change(key: .keyboardA, value: false)
      self.change(key: .keyboardS, value: false)
      self.change(key: .keyboardD, value: false)
      self.change(key: .keyboardSpacebar, value: false)
      self.change(key: .keyboardLeftShift, value: false)
    }
    
    // Prevent previous mouse events from affecting future frames.
    self.accumulatedMouseDelta = SIMD2(repeating: 0)
  }
  
  // Perform any necessary cleanup before closing the app.
  func closeApp(coordinator: Coordinator, forceExit: Bool) {
    // Prevent the mouse from staying trapped after the app closes.
    CGDisplayShowCursor(CGMainDisplayID())
    CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
    
    if forceExit {
      exit(0)
    }
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
    
    guard eventTracker.shouldAcceptInput else {
      // Do not accept keyboard input. Doing so leads to a bug where the
      // keyboard is disabled, even though the crosshair is active.
      return
    }
    
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
    
    guard eventTracker.shouldAcceptInput else {
      // Do not accept keyboard input. Doing so leads to a bug where the
      // keyboard is disabled, even though the crosshair is active.
      return
    }
    
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
    
    guard eventTracker.shouldAcceptInput else {
      // Do not accept keyboard input. Doing so leads to a bug where the
      // keyboard is disabled, even though the crosshair is active.
      return
    }

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
    // Define a constant for the movement speed: 1.0 nanometers per second
    // TODO: Smoothstep the speed along with FOV when sprinting.
    let speed: Float = 1.0
    let positionDelta = speed * Float(frameDelta) / 120
    
    // In Minecraft, WASD only affects horizontal position, even when flying.
    let azimuth = playerState.rotations.azimuth
    let basisVectorX = azimuth * SIMD3(1, 0, 0)
    let basisVectorZ = azimuth * SIMD3(0, 0, 1)
    
    // Check if W is pressed and move forward along the z-axis
    if read(key: .keyboardW) == true {
      playerState.position -= basisVectorZ * positionDelta
    }
    
    // Check if S is pressed and move backward along the z-axis
    if read(key: .keyboardS) == true {
      playerState.position += basisVectorZ * positionDelta
    }
    
    // Check if A is pressed and move left along the x-axis
    if read(key: .keyboardA) == true {
      playerState.position -= basisVectorX * positionDelta
    }
    
    // Check if D is pressed and move right along the x-axis
    if read(key: .keyboardD) == true {
      playerState.position += basisVectorX * positionDelta
    }
    
    // Check if spacebar is pressed and move up along the y-axis
    if read(key: .keyboardSpacebar) == true {
      playerState.position.y += positionDelta
    }
    
    // Check if left shift is pressed and move down along the y-axis
    if read(key: .keyboardLeftShift) == true {
      playerState.position.y -= positionDelta
    }
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

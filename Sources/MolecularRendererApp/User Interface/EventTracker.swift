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
  
  static let initialPlayerPosition: SIMD3<Float> = [0, 0, 1]
  
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
  
  class MotionKey {
    // Use atomics to bypass the crash when the main thread accesses this.
    private var active: ManagedAtomic<Bool> = ManagedAtomic(false)
    private var sprinting: ManagedAtomic<Bool> = ManagedAtomic(false)
    
    // The paired key. If you are currently sprinting, you should suppress the
    // sprinting on this key.
    unowned var pairedKey: MotionKey?
    
    // This number keeps decreasing to negative infinity each frame. Whenever
    // the key is pressed, it is manually reset to the timeout. This allows it
    // to detect a double-press for sprinting.
    private var timeoutBitPattern: ManagedAtomic<UInt64> =
      .init(Double(-1).bitPattern)
    
    private var timeoutLock: ManagedAtomic<Bool> = ManagedAtomic(false)
    
    private func acquireLock() {
      while true {
        let result = timeoutLock.compareExchange(
          expected: false, desired: true, ordering: .sequentiallyConsistent)
        if result.exchanged {
          return
        }
      }
    }
    
    private func releaseLock() {
      while true {
        let result = timeoutLock.compareExchange(
          expected: true, desired: false, ordering: .sequentiallyConsistent)
        if result.exchanged {
          return
        }
      }
    }
    
    func withLock<T>(_ closure: () -> T) -> T {
      acquireLock()
      let output = closure()
      releaseLock()
      return output
    }
    
    // Decrement the timeout by the delta between now and when you last entered
    // whatever code calls this.
    func _unsafe_decrementTimeout(elapsedTime: Double) {
      var bitPattern = timeoutBitPattern.load(ordering: .sequentiallyConsistent)
      var value = Double(bitPattern: bitPattern)
      value -= elapsedTime
      bitPattern = value.bitPattern
      timeoutBitPattern.store(bitPattern, ordering: .sequentiallyConsistent)
    }
    
    func _unsafe_timeoutExists() -> Bool {
      let bitPattern = timeoutBitPattern.load(ordering: .sequentiallyConsistent)
      return bitPattern > 0
    }
    
    func _unsafe_activate() {
      pairedKey!.withLock {
        pairedKey!._unsafe_suppressSprinting()
      }
      
      if active.load(ordering: .sequentiallyConsistent) {
        return
      }
      active.store(true, ordering: .sequentiallyConsistent)
      
      // Do not restart an existing timeout.
      let bitPattern = timeoutBitPattern.load(ordering: .sequentiallyConsistent)
      if Double(bitPattern: bitPattern) > 0 {
        precondition(!sprinting.load(ordering: .sequentiallyConsistent))
        sprinting.store(true, ordering: .sequentiallyConsistent)
      } else {
        // 0.3 second timeout for now.
        let bitPattern = Double(0.3   ).bitPattern
        timeoutBitPattern.store(bitPattern, ordering: .sequentiallyConsistent)
      }
    }
    
    func _unsafe_suppressSprinting() {
      let bitPattern = Double(-1).bitPattern
      timeoutBitPattern.store(bitPattern, ordering: .sequentiallyConsistent)
    }
    
    func _unsafe_deactivate() {
      // If it recognized a sprint now, you must double-tap all over again for
      // it to detect another sprint.
      if sprinting.load(ordering: .sequentiallyConsistent) {
        _unsafe_suppressSprinting()
      }
      
      active.store(false, ordering: .sequentiallyConsistent)
      sprinting.store(false, ordering: .sequentiallyConsistent)
    }
    
    func _unsafe_isSinglePressed() -> Bool {
      active.load(ordering: .sequentiallyConsistent)
    }
    
    func _unsafe_isDoublePressed() -> Bool {
      sprinting.load(ordering: .sequentiallyConsistent)
    }
  }
  
  // Use atomics to bypass the crash when the main thread accesses this.
  var keyboardWPressed = MotionKey()
  var keyboardAPressed = MotionKey()
  var keyboardSPressed = MotionKey()
  var keyboardDPressed = MotionKey()
  var keyboardSpacebarPressed = MotionKey()
  var keyboardShiftPressed = MotionKey()
  
  // P is for playing the simulation.
  var keyboardPPressed = MotionKey()
  
  // R is for resetting the simulation.
  var keyboardRPressed = MotionKey()
  
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
  
  var sprintingHistory = SprintingHistory()
  
  init() {
    self.playerState.position = Self.initialPlayerPosition
    
    keyboardWPressed.pairedKey = keyboardSPressed
    keyboardSPressed.pairedKey = keyboardWPressed
    keyboardAPressed.pairedKey = keyboardDPressed
    keyboardDPressed.pairedKey = keyboardAPressed
    keyboardSpacebarPressed.pairedKey = keyboardShiftPressed
    keyboardShiftPressed.pairedKey = keyboardSpacebarPressed
    keyboardPPressed.pairedKey = keyboardRPressed
    keyboardRPressed.pairedKey = keyboardPPressed
    
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
    if shouldAcceptInput, !read(key: .keyboardEscape).isSinglePressed {
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
      
      // Sprinting FOV should decrease even when the user is inactive.
      sprintingHistory.update(timestamp: CACurrentMediaTime(), sprinting: false)
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
    if key == .keyboardEscape {
      // Key down toggles the value, key up does nothing.
      _ = crosshairActive.loadThenLogicalXor(with: value, ordering: .relaxed)
    }
    
    var motionKey: MotionKey
    switch key {
    case .keyboardW:
      motionKey = keyboardWPressed
    case .keyboardA:
      motionKey = keyboardAPressed
    case .keyboardS:
      motionKey = keyboardSPressed
    case .keyboardD:
      motionKey = keyboardDPressed
    case .keyboardP:
      motionKey = keyboardPPressed
    case .keyboardR:
      motionKey = keyboardRPressed
    case .keyboardSpacebar:
      motionKey = keyboardSpacebarPressed
    case .keyboardLeftShift:
      motionKey = keyboardShiftPressed
    default:
      return
    }
    motionKey.withLock {
      if value == true {
        motionKey._unsafe_activate()
      } else {
        motionKey._unsafe_deactivate()
      }
    }
  }
  
  struct KeyReading {
    var motionKey: MotionKey?
    var isSinglePressed: Bool
    var isDoublePressed: Bool = false
    var timeoutExists: Bool = false
  }
  
  func read(key: KeyboardHIDUsage) -> KeyReading {
    if key == .keyboardEscape {
      // `true` means the crosshair is NOT active. This is analogous to
      // Minecraft, where ESC opens the game menu.
      let active = !crosshairActive.load(ordering: .relaxed)
      return KeyReading(isSinglePressed: active)
    }
    
    var motionKey: MotionKey
    switch key {
    case .keyboardW:
      motionKey = keyboardWPressed
    case .keyboardA:
      motionKey = keyboardAPressed
    case .keyboardS:
      motionKey = keyboardSPressed
    case .keyboardD:
      motionKey = keyboardDPressed
    case .keyboardP:
      motionKey = keyboardPPressed
    case .keyboardR:
      motionKey = keyboardRPressed
    case .keyboardSpacebar:
      motionKey = keyboardSpacebarPressed
    case .keyboardLeftShift:
      motionKey = keyboardShiftPressed
    default:
      fatalError("Unsupported key \(key)")
    }
    return motionKey.withLock {
      KeyReading(
        motionKey: motionKey,
        isSinglePressed: motionKey._unsafe_isSinglePressed(),
        isDoublePressed: motionKey._unsafe_isDoublePressed(),
        timeoutExists: motionKey._unsafe_timeoutExists())
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
    let positionDelta = speed * Float(frameDelta) / Float(
      Renderer.frameRateBasis)
    
    // In Minecraft, WASD only affects horizontal position, even when flying.
    let azimuth = playerState.rotations.azimuth
    let basisVectorX = azimuth * SIMD3(1, 0, 0)
    let basisVectorZ = azimuth * SIMD3(0, 0, 1)
    
    let readingW = read(key: .keyboardW)
    let readingS = read(key: .keyboardS)
    let readingA = read(key: .keyboardA)
    let readingD = read(key: .keyboardD)
    let readingSpacebar = read(key: .keyboardSpacebar)
    let readingLeftShift = read(key: .keyboardLeftShift)
    
    let currentTime = CACurrentMediaTime()
    if let lastTime {
      // Only do FOV changes for directions you look directly at.
      let readings = [readingW, readingSpacebar, readingLeftShift]
      for reading in readings where reading.timeoutExists {
        let delta = currentTime - lastTime
        let motionKey = reading.motionKey!
        motionKey.withLock {
          motionKey._unsafe_decrementTimeout(elapsedTime: delta)
        }
      }
      
      let sprinting = readings.contains(where: \.isDoublePressed)
      sprintingHistory.update(timestamp: currentTime, sprinting: sprinting)
    }
    lastTime = currentTime
    
    // Call this to use two different speeds for keys that can sprint.
    func delta(reading: KeyReading) -> Float {
      if reading.isDoublePressed {
        print("Sprinting @ \(CACurrentMediaTime())")
        return 2 * positionDelta
        
      } else {
        return positionDelta
      }
    }
    
    // Check if W is pressed and move forward along the z-axis
    if readingW.isSinglePressed {
      playerState.position -= basisVectorZ * delta(reading: readingW)
    }
    
    // Check if S is pressed and move backward along the z-axis
    if readingS.isSinglePressed {
      playerState.position += basisVectorZ * delta(reading: readingS)
    }
    
    // Check if A is pressed and move left along the x-axis
    if readingA.isSinglePressed {
      playerState.position -= basisVectorX * delta(reading: readingA)
    }
    
    // Check if D is pressed and move right along the x-axis
    if readingD.isSinglePressed {
      playerState.position += basisVectorX * delta(reading: readingD)
    }
    
    // Check if spacebar is pressed and move up along the y-axis
    if readingSpacebar.isSinglePressed {
      playerState.position.y += delta(reading: readingSpacebar)
    }
    
    // Check if left shift is pressed and move down along the y-axis
    if readingLeftShift.isSinglePressed {
      playerState.position.y -= delta(reading: readingLeftShift)
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

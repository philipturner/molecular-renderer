//
//  InputEvents.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/15/23.
//

import Atomics
import AppKit
import KeyCodes

// Stores the events that occurred this frame, performs certain actions based on
// each event, then clears the list of events when necessary.
class EventTracker {
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
  
  var playerPosition: SIMD3<Float> = SIMD3(repeating: 0)
  
  // TODO: When the crosshair is inactive, disallow WASD and mouse. We don't
  // want the user to mess with a predefined player position accidentally.
  var crosshairActive: ManagedAtomic<Bool> = ManagedAtomic(false)
  
  init() {
    NSEvent.addLocalMonitorForEvents(matching: .mouseExited) { event in
      self.mouseInWindow.store(false, ordering: .relaxed)
      return event
    }
    
    NSEvent.addLocalMonitorForEvents(matching: .mouseEntered) { event in
      self.mouseInWindow.store(true, ordering: .relaxed)
      return event
    }
  }
  
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
      return crosshairActive.load(ordering: .relaxed)
    default:
      fatalError("Unsupported key \(key)")
    }
  }
}

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
  
  // TODO: Will need to lock the mouse pointer inside the Window, like Minecraft.
}

extension EventTracker {
  func update(frameDelta: Int) {
    if !windowInForeground.load(ordering: .relaxed) ||
        !mouseInWindow.load(ordering: .relaxed) {
      // Do not move the player right now.
      return
    }
    
    var pressedKeys: [String] = []
    
    // Define a constant for the movement speed
    // 1.0 nanometers per second
    let speed: Float = 1.0
    let positionDelta = speed * Float(frameDelta) / 120
    
    // Check if W is pressed and move forward along the z-axis
    if read(key: .keyboardW) == true {
      pressedKeys.append("W")
      playerPosition.z -= positionDelta
    }
    
    // Check if S is pressed and move backward along the z-axis
    if read(key: .keyboardS) == true {
      pressedKeys.append("S")
      playerPosition.z += positionDelta
    }
    
    // Check if A is pressed and move left along the x-axis
    if read(key: .keyboardA) == true {
      pressedKeys.append("A")
      playerPosition.x -= positionDelta
    }
    
    // Check if D is pressed and move right along the x-axis
    if read(key: .keyboardD) == true {
      pressedKeys.append("D")
      playerPosition.x += positionDelta
    }
    
    // Check if spacebar is pressed and move up along the y-axis
    if read(key: .keyboardSpacebar) == true {
      pressedKeys.append("SPACE")
      playerPosition.y += positionDelta
    }
    
    // Check if left shift is pressed and move down along the y-axis
    if read(key: .keyboardLeftShift) == true {
      pressedKeys.append("LSHIFT")
      playerPosition.y -= positionDelta
    }
    
    if read(key: .keyboardEscape) == true {
//      pressedKeys.append("ESC")
    }
    
//    if !pressedKeys.isEmpty {
//      let message = String(pressedKeys.joined(separator: " "))
//      print(message)
//    }
  }
}

extension EventTracker {
  // Perform any necessary cleanup, then close the app.
  func closeApp(coordinator: Coordinator) {
    exit(0)
  }
}

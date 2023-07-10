//
//  Coordinator.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/16/23.
//

import SwiftUI

class Coordinator: NSResponder, ObservableObject {
  var renderer: Renderer!
  var vsyncHandler: VsyncHandler!
  var eventTracker: EventTracker!
  
  // Automatically launch on the main screen.
  var forcedToMainScreen = false
  
  // A scene view to display the 3D environment.
  var view: RendererView!
  
  // A state variable to control the visibility of the crosshair.
  @Published var showCrosshair = false
  
  override init() {
    super.init()
    
    // Previously, MolecularRenderer was finicky in that it required a full
    // restart + careful window evasion to break out of having the mouse
    // trapped. That part should be fixed now, although the long stutter at app
    // startup hasn't been fixed.
    do {
      NSWorkspace.shared.notificationCenter.addObserver(
        self, selector: #selector(self.disconnectMouse),
        name: NSWorkspace.willPowerOffNotification, object: nil)
      
      NSWorkspace.shared.notificationCenter.addObserver(
        self, selector: #selector(self.disconnectMouse),
        name: NSWorkspace.didWakeNotification, object: nil)
      
      NSWorkspace.shared.notificationCenter.addObserver(
        self, selector: #selector(self.disconnectMouse),
        name: NSWorkspace.willSleepNotification, object: nil)
      
      NSWorkspace.shared.notificationCenter.addObserver(
        self, selector: #selector(self.disconnectMouse),
        name: NSWorkspace.screensDidSleepNotification, object: nil)
    }
    
    self.view = RendererView()
    self.view.initializeResources(coordinator: self)
    
    view.metalLayer.framebufferOnly = false
    view.metalLayer.allowsNextDrawableTimeout = false
    view.metalLayer.pixelFormat = .rgb10a2Unorm
    
    self.eventTracker = EventTracker()
    
    self.renderer = Renderer(coordinator: self)
    view.metalLayer.device = MTLCreateSystemDefaultDevice()!
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // This function would adapt to user-specific sizes, but for now we disallow
  // resizing.
  func drawableResize(_ size: CGSize) {
    if size.width != ContentView.size || size.height != ContentView.size {
      fatalError("Size cannot change.")
    }
  }
  
  // TODO: Try merging this function with `showCursor()`.
  @objc func disconnectMouse() {
    CGDisplayShowCursor(CGMainDisplayID())
    CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
    
    showCrosshair = false
    eventTracker.crosshairActive.store(showCrosshair, ordering: .relaxed)
  }
}

extension Coordinator {
  func updateUI() {
    if !forcedToMainScreen {
      defer { forcedToMainScreen = true }
      
      let bestScreen = NSScreen.screens.max(by: {
        $0.maximumFramesPerSecond < $1.maximumFramesPerSecond
      })!
      let centerX = bestScreen.visibleFrame.midX
      let centerY = bestScreen.visibleFrame.midY
      let scaleFactor = bestScreen.backingScaleFactor

      let windowSize = ContentView.size / scaleFactor
      let leftX = centerX - windowSize / 2
      let upperY = centerY - windowSize / 2
      let origin = CGPoint(x: leftX, y: upperY)
      let size = CGSize(width: windowSize, height: windowSize)
      let frame = CGRect(origin: origin, size: size)
      view.window!.setFrame(frame, display: true)
    }
    
    let refreshRate = view.window!.screen!.maximumFramesPerSecond
    vsyncHandler.currentRefreshRate.store(refreshRate, ordering: .relaxed)
    
    let succeeded = view.window!.makeFirstResponder(self)
    if !succeeded {
      print("Could not become first responder. Exiting the app.")
      CGDisplayShowCursor(CGMainDisplayID())
      CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
      exit(0)
    }
  }
  
  func hideCursor() {
    CGDisplayHideCursor(CGMainDisplayID())
    CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
  }
  
  func showCursor() {
    let windowFrame = self.view.window!.frame
    let windowScreen = self.view.window!.screen!
    
    // WARNING: The X and Y hacks only work on the MacBook's display. For
    // any other display, I cannot think of a workaround. The cursor will
    // not be repositioned on such displays.
    if windowScreen == NSScreen.screens[0] {
      let backingScaleFactor = self.view.backingScaleFactor
      let originX = windowFrame.origin.x * backingScaleFactor
      var cursorNewX = originX / view.backingScaleFactor
      cursorNewX += view.window!.frame.width / 2
      
      // Y is offset in a wierd way. Take the bottom of the screen, move up
      // `view.window!.frame.height` units. Now you are at the window's origin
      // in global display space.
      var cursorNewY = windowScreen.frame.height - windowFrame.height
      cursorNewY -= windowFrame.origin.y
      cursorNewY += windowFrame.width / 2
      
      // Account for the extra bar at the top of the window.
      cursorNewY += windowFrame.height - windowFrame.width
      let cursorPoint = CGPoint(x: cursorNewX, y: cursorNewY)
      CGWarpMouseCursorPosition(cursorPoint)
    }
    
    CGDisplayShowCursor(CGMainDisplayID())
    CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
  }
}

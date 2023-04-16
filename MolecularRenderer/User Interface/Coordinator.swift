//
//  Coordinator.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/16/23.
//

import SwiftUI

class Coordinator: NSResponder, ObservableObject {
  var renderer: Renderer!
  var displayLink: CVDisplayLink!
  var eventTracker: EventTracker!
  
  // Automatically launch on the main screen.
  var forcedToMainScreen = false
  
  // A scene view to display the 3D environment
  var view: RendererView!
  
  // A state variable to control the visibility of the crosshair
  @Published var showCrosshair = false
  
  override init() {
    super.init()
    
    self.view = RendererView()
    self.view.initializeResources(coordinator: self)
    
    view.metalLayer.framebufferOnly = false
    view.metalLayer.allowsNextDrawableTimeout = false
    view.metalLayer.pixelFormat = .rgb10a2Unorm
    
    self.renderer = Renderer(view: view)
    view.metalLayer.device = renderer.device
    
    self.eventTracker = EventTracker()
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
}

extension Coordinator {
  func setupCVDisplayLink(screen: NSScreen) {
    // Set up the display link.
    checkCVDisplayError(
      CVDisplayLinkCreateWithActiveCGDisplays(&self.displayLink))
    checkCVDisplayError(CVDisplayLinkSetOutputHandler(displayLink) {
      // Must access the UI from the main thread.
      DispatchQueue.main.async(execute: self.updateUI)
      return self.renderer.vsyncHandler($0, $1, $2, $3, $4)
    })
    checkCVDisplayError(
      CVDisplayLinkSetCurrentCGDisplay(
        displayLink, view.window!.screen!.screenNumber))
    checkCVDisplayError(CVDisplayLinkStart(displayLink))
    
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(
      self, selector: #selector(windowWillClose),
      name: NSWindow.willCloseNotification, object: view.window!)
  }
  
  @objc func windowWillClose(notification: NSNotification) {
    if (notification.object! as AnyObject) === view.window! {
      checkCVDisplayError(CVDisplayLinkStop(self.displayLink))
    }
  }
  
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
    renderer.currentRefreshRate.store(refreshRate, ordering: .relaxed)
    
    let succeeded = view.window!.makeFirstResponder(self)
    if !succeeded {
      print("Could not become first responder. Exiting the app.")
      eventTracker.closeApp(coordinator: self)
    }
    
    let crosshairActive = eventTracker.crosshairActive.load(ordering: .relaxed)
    if self.showCrosshair != crosshairActive {
      self.showCrosshair = crosshairActive
    }
  }
}

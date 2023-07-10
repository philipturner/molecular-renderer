//
//  VsyncHandler.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/9/23.
//

import AppKit
import Atomics
import Foundation
import MolecularRenderer

class VsyncHandler {
  unowned let coordinator: Coordinator
  var displayLink: CVDisplayLink
  var mainThreadSemaphore: DispatchSemaphore = .init(value: 1)
  
  var startTimeStamp: CVTimeStamp?
  var previousTimeStamp: CVTimeStamp?
  
  // Data for robustly synchronizing with the refresh rate.
  var currentRefreshRate: ManagedAtomic<Int>
  var uniqueFrameID: Int = 0 // for random numbers
  var frameID: Int = 0
  var adjustedFrameID: Int = -1
  var sustainedMisalignment: Int = 0
  var sustainedMisalignmentDuration: Int = 0
  var sustainedAlignmentDuration: Int = 0
  
  init(coordinator: Coordinator, screen: NSScreen) {
    self.coordinator = coordinator
    
    MRSetFrameRate(120)
    currentRefreshRate = .init(120)
    
    // Set up the display link.
    var _displayLink: CVDisplayLink?
    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink)
    self.displayLink = _displayLink!
    
    CVDisplayLinkSetOutputHandler(displayLink) { [self] in
      // Prevent oversubscription of the main thread.
      mainThreadSemaphore.wait()
      
      // Must access the UI from the main thread.
      DispatchQueue.main.async { [self] in
        coordinator.updateUI()
        mainThreadSemaphore.signal()
      }
      
      let currentTimeStamp = $2.pointee
      _ = ($0, $1, $3, $4)
      previousTimeStamp = currentTimeStamp
      
      if startTimeStamp == nil {
        startTimeStamp = currentTimeStamp
      }
      
      coordinator.renderer.update()
      return kCVReturnSuccess
    }
    
    let window = coordinator.view.window!
    let screenNumber = window.screen!.deviceDescription[
      NSDeviceDescriptionKey("NSScreenNumber")] as! NSNumber
    CVDisplayLinkSetCurrentCGDisplay(displayLink, screenNumber.uint32Value)
    CVDisplayLinkStart(displayLink)
    
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(
      self, selector: #selector(self.windowWillClose),
      name: NSWindow.willCloseNotification, object: window)
  }
}

extension VsyncHandler {
  @objc func windowWillClose(notification: NSNotification) {
    exit(0)
  }
  
  func frames(start: CVTimeStamp, end: CVTimeStamp) -> Double {
#if arch(arm64)
    let ticksPerSecond: Int = 24 * 1000 * 1000
    let ticksPerFrame = ticksPerSecond / 120
#else
#error("This does not work on x86.")
#endif
    
    let deltaTicks = max(0, Int(end.hostTime) - Int(start.hostTime))
    return Double(deltaTicks) / Double(ticksPerFrame)
  }
  
  func seconds(start: CVTimeStamp, end: CVTimeStamp) -> Double {
#if arch(arm64)
    let ticksPerSecond: Int = 24 * 1000 * 1000
#else
#error("This does not work on x86.")
#endif
    
    let deltaTicks = max(0, Int(end.hostTime) - Int(start.hostTime))
    return Double(deltaTicks) / Double(ticksPerSecond)
  }
  
  // Time per frame in multiples of 120 Hz.
  func frameStep() -> Int {
    let current = currentRefreshRate.load(ordering: .relaxed)
    let frameRate = 120
    precondition(
      frameRate % current == 0, "Frame rate not divisible into \(frameRate).")
    return max(frameRate / current, 1)
  }
  
  // Returns the frame delta.
  func updateFrameID() -> Int {
    uniqueFrameID += 1
    frameID += 1
    
    let previousFrameID = adjustedFrameID
    var nextFrameID = previousFrameID
    var targetFrameID = Int(rint(
      frames(start: startTimeStamp!, end: previousTimeStamp!)))
    let step = frameStep()
    
    // Despite my best efforts, this is still much less robust on 60 Hz than on
    // 120 Hz. Porting to lower refresh-rate monitors is not a priority.
    while nextFrameID % step > 0 {
      nextFrameID -= 1
    }
    while targetFrameID % step > 0 {
      targetFrameID -= 1
    }
    nextFrameID += step
    
    if abs(targetFrameID - nextFrameID) >= 2 * step {
      // Exponentially gravitate toward the correct position.
      // This may become unstable in certain ill-conditioned situations.
      nextFrameID += (targetFrameID - nextFrameID) / 2
    } else if abs(targetFrameID - nextFrameID) == step {
      // Wait a while to smooth out noise.
      if sustainedMisalignmentDuration >= 10 ||
         sustainedAlignmentDuration >= 10 {
        nextFrameID = targetFrameID
      }
    }
    
    if targetFrameID != nextFrameID {
      sustainedAlignmentDuration = 0
      let delta = targetFrameID - nextFrameID
      if delta == sustainedMisalignment {
        sustainedMisalignmentDuration += 1
      } else {
        sustainedMisalignment = delta
        sustainedMisalignmentDuration = 0
      }
    } else {
      sustainedMisalignment = 0
      sustainedMisalignmentDuration = 0
      sustainedAlignmentDuration += 1
    }
    adjustedFrameID = nextFrameID
    
    return nextFrameID - previousFrameID
  }
}



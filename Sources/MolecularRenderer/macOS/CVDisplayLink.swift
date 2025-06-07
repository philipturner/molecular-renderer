#if os(macOS)
import QuartzCore

// Suppressing warnings:
// https://stackoverflow.com/questions/31540446/how-to-silence-a-warning-in-swift

protocol CVDisplayLinkProtocol {
  func CVDisplayLinkCreateWithCGDisplay(
    _ displayID: CGDirectDisplayID,
    _ displayLinkOut: UnsafeMutablePointer<CVDisplayLink?>
  )
  
  func CVDisplayLinkSetOutputHandler(
    _ displayLink: CVDisplayLink,
    _ handler: @escaping CVDisplayLinkOutputHandler
  )
  
  func CVDisplayLinkGetCurrentCGDisplay(_ displayLink: CVDisplayLink) -> Int
  func CVDisplayLinkStart(_ displayLink: CVDisplayLink)
  func CVDisplayLinkStop(_ displayLink: CVDisplayLink)
}

struct CVDisplayLinkStruct: CVDisplayLinkProtocol {
  @available(macOS, deprecated: 15.0)
  func CVDisplayLinkCreateWithCGDisplay(
    _ displayID: CGDirectDisplayID,
    _ displayLinkOut: UnsafeMutablePointer<CVDisplayLink?>
  ) {
    QuartzCore.CVDisplayLinkCreateWithCGDisplay(displayID, displayLinkOut)
  }
  
  @available(macOS, deprecated: 15.0)
  func CVDisplayLinkSetOutputHandler(
    _ displayLink: CVDisplayLink,
    _ handler: @escaping CVDisplayLinkOutputHandler
  ) {
    QuartzCore.CVDisplayLinkSetOutputHandler(displayLink, handler)
  }
  
  @available(macOS, deprecated: 15.0)
  func CVDisplayLinkGetCurrentCGDisplay(_ displayLink: CVDisplayLink) -> Int {
    let rawID = QuartzCore.CVDisplayLinkGetCurrentCGDisplay(displayLink)
    return Int(rawID)
  }
  
  @available(macOS, deprecated: 15.0)
  func CVDisplayLinkStart(_ displayLink: CVDisplayLink) {
    QuartzCore.CVDisplayLinkStart(displayLink)
  }
  
  @available(macOS, deprecated: 15.0)
  func CVDisplayLinkStop(_ displayLink: CVDisplayLink) {
    QuartzCore.CVDisplayLinkStop(displayLink)
  }
}

#endif

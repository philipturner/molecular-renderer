struct CrashInfoDescriptor {
  var bufferContents: [UInt32]?
  var clockFrames: Int?
  var displayFrameRate: Int?
  var frameID: Int?
  var memorySlotCount: Int?
  var worldDimension: Float?
}

class CrashInfo {
  init(descriptor: CrashInfoDescriptor) {
    guard let bufferContents = descriptor.bufferContents,
          let clockFrames = descriptor.clockFrames,
          let displayFrameRate = descriptor.displayFrameRate,
          let frameID = descriptor.frameID,
          let memorySlotCount = descriptor.memorySlotCount,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Diagnose the wall clock time when the error was registered.
    // Diagnose the frame when it was registered.
    // Diagnose the frame when it was thrown.
    // Approximate the wall time when the error was thrown.
  }
  
  var message: String {
    return """
    Error thrown in shader code.
    
    TODO
    TODO
    TODO
    
    TODO
    TODO
    TODO
    """
  }
}

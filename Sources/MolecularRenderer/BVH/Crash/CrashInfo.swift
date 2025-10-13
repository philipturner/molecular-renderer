struct CrashInfoDescriptor {
  var bufferContents: [UInt32]?
  var clockFrames: Int?
  var displayFrameRate: Int?
  var frameID: Int?
  var memorySlotCount: Int?
  var worldDimension: Float?
}

class CrashInfo {
  let registeredFrameID: Int
  let thrownFrameID: Int
  let registeredClockTime: Double
  let thrownClockTime: Double // approximate
  
  init(descriptor: CrashInfoDescriptor) {
    guard let bufferContents = descriptor.bufferContents,
          let clockFrames = descriptor.clockFrames,
          let displayFrameRate = descriptor.displayFrameRate,
          let frameID = descriptor.frameID,
          let memorySlotCount = descriptor.memorySlotCount,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }
    
    self.registeredFrameID = frameID
    self.thrownFrameID = frameID - 3
    self.registeredClockTime = Double(clockFrames) / Double(displayFrameRate)
    self.thrownClockTime = Double(clockFrames - 3) / Double(displayFrameRate)
    
    // Diagnose the position of the lower corner.
    
    // Error message 2:
    // requested vacant slot #X
    // vacant slots: vacantSlotCount / memorySlotCount
    
    // Error message 3:
    // total atom count
    // maximum allowed is 3072
    
    // Error message 4:
    // small reference count
    // maximum allowed is 20480
  }
  
  var message: String {
    func format(_ seconds: Double) -> String {
      String(format: "%.3f", seconds)
    }
    
    return """
    Error thrown in shader code.
    
    Registered while encoding frame \(registeredFrameID).
    Thrown during frame \(thrownFrameID).
    Registered \(format(registeredClockTime)) s after application launch.
    Thrown approximately \(format(thrownClockTime)) s after application launch.
    
    TODO
    TODO
    TODO
    """
  }
}

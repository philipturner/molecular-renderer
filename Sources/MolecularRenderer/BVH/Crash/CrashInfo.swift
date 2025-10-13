struct CrashInfoDescriptor {
  var bufferContents: [UInt32]?
  var clockTime: Float?
  var frameID: Int?
  var memorySlotCount: Int?
  var worldDimension: Float?
}

class CrashInfo {
  init(descriptor: CrashInfoDescriptor) {
    guard let bufferContents = descriptor.bufferContents,
          let clockTime = descriptor.clockTime,
          let frameID = descriptor.frameID,
          let memorySlotCount = descriptor.memorySlotCount,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Diagnose the wall clock time when the error was registered.
    // Diagnose the frame when it was registered.
    // Diagnose the frame when it was thrown.
  }
}

enum CrashType {
  case outOfMemory(Int, Int, Int)
  case tooManyAtoms(Int, Int, Int)
  case tooManyReferences(Int)
  case unknown(Int)
}

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
  
  let lowerCorner: SIMD3<Float>
  let crashType: CrashType
  
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
    let voxelCoords = SIMD3<UInt32>(
      bufferContents[1],
      bufferContents[2],
      bufferContents[3])
    self.lowerCorner = SIMD3<Float>(voxelCoords) * 2 - (worldDimension / 2)
    
    switch bufferContents[0] {
    case 2:
      let requestedSlotID = Int(bufferContents[4])
      let vacantSlotCount = Int(bufferContents[5])
      self.crashType = .outOfMemory(
        requestedSlotID, vacantSlotCount, memorySlotCount)
    case 3:
      let newAtomCount = Int(bufferContents[4])
      let existingAtomCount = Int(bufferContents[5])
      let addedAtomCount = Int(bufferContents[6])
      self.crashType = .tooManyAtoms(
        newAtomCount, existingAtomCount, addedAtomCount)
    case 4:
      let smallReferenceCount = Int(bufferContents[4])
      self.crashType = .tooManyReferences(smallReferenceCount)
    default:
      let errorCode = Int(bufferContents[0])
      self.crashType = .unknown(errorCode)
    }
  }
  
  var message: String {
    func format(_ seconds: Double) -> String {
      String(format: "%.3f", seconds)
    }
    
    func errorCodePortion() -> String {
      switch crashType {
      case .outOfMemory(let requestedSlotID, let vacantSlotCount, let memorySlotCount):
        return """
        Requested vacant slot #\(requestedSlotID)
        Vacant slots: \(vacantSlotCount) / \(memorySlotCount)
        """
      case .tooManyAtoms(let newAtomCount, let existingAtomCount, let addedAtomCount):
        return """
        Voxel had \(newAtomCount) atoms.
        \(existingAtomCount) existed before this frame, \(addedAtomCount) were added.
        Maximum allowed: 3072
        """
      case .tooManyReferences(let smallReferenceCount):
        return """
        Voxel had \(smallReferenceCount) 16-bit references.
        Maximum allowed: 20480
        """
      case .unknown(let errorCode):
        return """
        Invalid error code: \(errorCode)
        """
      }
    }
    
    return """
    Error thrown in shader code.
    
    Registered while encoding frame \(registeredFrameID).
    Thrown during frame \(thrownFrameID).
    Registered \(format(registeredClockTime)) s after application launch.
    Thrown approximately \(format(thrownClockTime)) s after application launch.
    
    Voxel lower corner: \(lowerCorner)
    Voxel upper corner: \(lowerCorner + Float(2))
    \(errorCodePortion())
    """
  }
}

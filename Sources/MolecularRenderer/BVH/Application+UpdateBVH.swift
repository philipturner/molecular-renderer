#if os(Windows)
import SwiftCOM
import WinSDK
#endif

public struct PerformanceMeter {
  public var minimum: Int = .max
  
  public init() {
    
  }
  
  public mutating func integrate(_ measurement: Int) {
    if measurement < minimum {
      minimum = measurement
    }
  }
  
  public static func pad(_ latency: Int) -> String {
    var output = "\(latency)"
    while output.count < 5 {
      output = " " + output
    }
    return output
  }
}

extension Application {
  nonisolated(unsafe)
  static var updateMeter = PerformanceMeter()
  
  public func checkCrashBuffer(frameID: Int) {
    if frameID >= 3 {
      let elementCount = CounterResources.crashBufferSize / 4
      var output = [UInt32](repeating: .zero, count: elementCount)
      bvhBuilder.counters.crashBuffer.read(
        data: &output,
        inFlightFrameID: frameID % 3)
      
      if output[0] != 1 {
        var crashInfoDesc = CrashInfoDescriptor()
        crashInfoDesc.bufferContents = output
        crashInfoDesc.clockFrames = clock.frames
        crashInfoDesc.displayFrameRate = display.frameRate
        crashInfoDesc.frameID = frameID
        crashInfoDesc.memorySlotCount = bvhBuilder.voxels.memorySlotCount
        crashInfoDesc.worldDimension = bvhBuilder.voxels.worldDimension
        let crashInfo = CrashInfo(descriptor: crashInfoDesc)
        
        fatalError(crashInfo.message)
      }
    }
  }
  
  public func checkExecutionTime(frameID: Int) {
    if frameID >= 3 {
      #if os(Windows)
      let destinationBuffer = bvhBuilder.counters
        .queryDestinationBuffers[frameID % 3]
      var output = [UInt64](repeating: .zero, count: 4)
      output.withUnsafeMutableBytes { bufferPointer in
        destinationBuffer.read(output: bufferPointer)
      }
      
      let timestampFrequency = try! device.commandQueue.d3d12CommandQueue
        .GetTimestampFrequency()
      func latencyMicroseconds(startIndex: Int) -> Int {
        let startCounter = output[startIndex]
        let endCounter = output[startIndex + 1]
        var elapsedTime = Double(endCounter - startCounter)
        elapsedTime /= Double(timestampFrequency)
        
        return Int(elapsedTime * 1e6)
      }
      
      let updateBVHLatency = latencyMicroseconds(startIndex: 0)
      let renderLatency = latencyMicroseconds(startIndex: 2)
      #else
      var updateBVHLatency: Int = 0
      var renderLatency: Int = 0
      bvhBuilder.counters.queue.sync {
        updateBVHLatency = bvhBuilder.counters
          .updateBVHLatencies[frameID % 3]
        renderLatency = bvhBuilder.counters
          .renderLatencies[frameID % 3]
      }
      #endif
      
      // Edit this code to inspect GPU-side performance.
      Self.updateMeter.integrate(updateBVHLatency)
      print(Self.updateMeter.minimum)
      _ = renderLatency
    }
  }
  
  public func updateBVH(inFlightFrameID: Int) {
    let transaction = atoms.registerChanges()
    
    device.commandQueue.withCommandList { commandList in
      #if os(Windows)
      try! commandList.d3d12CommandList.EndQuery(
        bvhBuilder.counters.queryHeap,
        D3D12_QUERY_TYPE_TIMESTAMP,
        0)
      
      // Bind the descriptor heap.
      commandList.setDescriptorHeap(descriptorHeap)
      #endif
      
      bvhBuilder.purgeResources(
        commandList: commandList)
      bvhBuilder.setupGeneralCounters(
        commandList: commandList)
      bvhBuilder.upload(
        transaction: transaction,
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      
      // Encode the remove process.
      bvhBuilder.removeProcess1(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      bvhBuilder.removeProcess2(
        commandList: commandList)
      bvhBuilder.removeProcess3(
        commandList: commandList)
      bvhBuilder.removeProcess4(
        commandList: commandList)
      
      // Encode the add process.
      bvhBuilder.addProcess1(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      bvhBuilder.addProcess2(
        commandList: commandList)
      bvhBuilder.addProcess3(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      
      // Encode the rebuild process.
      bvhBuilder.rebuildProcess1(
        commandList: commandList)
      bvhBuilder.rebuildProcess2(
        commandList: commandList)
      
      #if os(Windows)
      try! commandList.d3d12CommandList.EndQuery(
        bvhBuilder.counters.queryHeap,
        D3D12_QUERY_TYPE_TIMESTAMP,
        1)
      
      let destinationBuffer = bvhBuilder.counters
        .queryDestinationBuffers[inFlightFrameID]
      try! commandList.d3d12CommandList.ResolveQueryData(
        bvhBuilder.counters.queryHeap,
        D3D12_QUERY_TYPE_TIMESTAMP,
        0,
        2,
        destinationBuffer.d3d12Resource,
        0)
      #endif
      
      #if os(macOS)
      nonisolated(unsafe)
      let selfReference = self
      commandList.mtlCommandBuffer.addCompletedHandler { commandBuffer in
        selfReference.bvhBuilder.counters.queue.sync {
          var executionTime = commandBuffer.gpuEndTime
          executionTime -= commandBuffer.gpuStartTime
          let latencyMicroseconds = Int(executionTime * 1e6)
          selfReference.bvhBuilder.counters
            .updateBVHLatencies[inFlightFrameID] = latencyMicroseconds
        }
      }
      #endif
    }
  }
  
  public func forgetIdleState(inFlightFrameID: Int) {
    device.commandQueue.withCommandList { commandList in
      // Bind the descriptor heap.
      #if os(Windows)
      commandList.setDescriptorHeap(descriptorHeap)
      #endif
      
      bvhBuilder.resetMotionVectors(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      bvhBuilder.resetVoxelMarks(
        commandList: commandList)
      bvhBuilder.counters.crashBuffer.download(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      
      #if os(Windows)
      bvhBuilder.computeUAVBarrier(commandList: commandList)
      #endif
    }
    
    // Delete the transactionArgs state variable.
    bvhBuilder.transactionArgs = nil
  }
}

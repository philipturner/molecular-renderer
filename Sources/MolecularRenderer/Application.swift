import AppKit

public struct ApplicationDescriptor {
  public var display: Display?
  
  public init() {
    
  }
}

public class Application {
  public var clock: Clock
  public var display: Display
  var view: View
  var window: Window
  
  public init(descriptor: ApplicationDescriptor) {
    guard let display = descriptor.display else {
      fatalError("Descriptor was incomplete.")
    }
    self.display = display
    
    clock = Clock()
    view = View(display: display)
    window = Window(display: display)
    
    window.view = view
    view.windowReference = window
  }
  
  public func run() {
    let application = NSApplication.shared
    application.delegate = window
    application.setActivationPolicy(.regular)
    application.activate(ignoringOtherApps: true)
    application.run()
  }
}

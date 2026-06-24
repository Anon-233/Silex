import Foundation
import SilexCore

let delegate = SMARTServiceListenerDelegate()
let listener = NSXPCListener(machServiceName: SMARTServiceConstants.machServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.current.run()

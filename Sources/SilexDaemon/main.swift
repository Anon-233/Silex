import Foundation
import SilexCore

let idleTerminator = ServiceIdleTerminator()
let delegate = SMARTServiceListenerDelegate(idleTerminator: idleTerminator)
let listener = NSXPCListener(machServiceName: SMARTServiceConstants.machServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.current.run()

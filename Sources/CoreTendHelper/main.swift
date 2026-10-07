import Foundation
import HelperProtocol

// CoreTend's system helper: a launchd daemon (root) started on demand when CoreTend calls its Mach
// service. Only CoreTend signed by its team gets through; the system checks it on every message.

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = HelperIdentity.interface()
        connection.exportedObject = HelperService(clientUID: connection.effectiveUserIdentifier)
        connection.resume()
        return true
    }
}

let delegate = ListenerDelegate()
let listener = NSXPCListener(machServiceName: HelperIdentity.machService)
listener.setConnectionCodeSigningRequirement(HelperIdentity.clientRequirement)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()

import Network
import Observation

@Observable
final class WifiMonitor: @unchecked Sendable {
    static let shared = WifiMonitor()

    private(set) var isConnected: Bool = false

    private let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let queue = DispatchQueue(label: "com.studyreef.wifi-monitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}

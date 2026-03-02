import Foundation
import Network

struct DiscoveredGateway: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let displayName: String
    let host: String
    let port: UInt16
    let tlsEnabled: Bool

    var urlString: String {
        let scheme = tlsEnabled ? "https" : "http"
        return "\(scheme)://\(host):\(port)"
    }
}

@MainActor
class BonjourDiscovery: ObservableObject {
    @Published var discoveredGateways: [DiscoveredGateway] = []
    @Published var isSearching = false

    private var browser: NWBrowser?

    func startBrowsing() {
        isSearching = true
        discoveredGateways = []

        let params = NWParameters()
        params.includePeerToPeer = false

        browser = NWBrowser(
            for: .bonjour(type: "_openclaw-gw._tcp", domain: "local."),
            using: params
        )

        browser?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .failed:
                    self?.isSearching = false
                case .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                self?.processResults(results)
            }
        }

        browser?.start(queue: .main)
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    private func processResults(_ results: Set<NWBrowser.Result>) {
        var gateways: [DiscoveredGateway] = []

        for result in results {
            guard case .service(let name, _, _, _) = result.endpoint else { continue }

            var displayName = name
            var lanHost = "\(name).local"
            var gatewayPort: UInt16 = 18789
            var tlsEnabled = false

            // Parse TXT records from metadata
            if case .bonjour(let txtRecord) = result.metadata {
                txtRecord.dictionary.forEach { key, value in
                    switch key {
                    case "displayName": displayName = value
                    case "lanHost": lanHost = value
                    case "gatewayPort": gatewayPort = UInt16(value) ?? 18789
                    case "gatewayTls": tlsEnabled = value == "1"
                    default: break
                    }
                }
            }

            gateways.append(DiscoveredGateway(
                name: name,
                displayName: displayName,
                host: lanHost,
                port: gatewayPort,
                tlsEnabled: tlsEnabled
            ))
        }

        discoveredGateways = gateways
    }
}

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var gatewayClient: GatewayHTTPClient
    @EnvironmentObject var bonjourDiscovery: BonjourDiscovery

    @State private var gatewayURL: String = UserDefaults.standard.string(forKey: "gatewayURL") ?? "http://localhost:18789"
    @State private var authToken: String = (try? KeychainHelper.shared.get("gatewayToken")) ?? ""
    @State private var isTestingConnection = false
    @State private var testResult: String? = nil
    @State private var showToken = false
    @State private var launchAtLogin = LoginItemManager.shared.isEnabled

    var body: some View {
        Form {
            Section("Gateway Connection") {
                LabeledContent("Gateway URL") {
                    TextField("http://host:18789", text: $gatewayURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                LabeledContent("Auth Token") {
                    HStack {
                        if showToken {
                            TextField("Token", text: $authToken)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("Token", text: $authToken)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button(showToken ? "Hide" : "Show") {
                            showToken.toggle()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                }

                HStack {
                    Button("Save & Test Connection") {
                        saveSettings()
                        testConnection()
                    }
                    .disabled(isTestingConnection)

                    if isTestingConnection {
                        ProgressView().scaleEffect(0.7)
                    }

                    Spacer()

                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.hasPrefix("✓") ? Color.green : Color.red)
                    }
                }
            }

            Section("Bonjour Discovery") {
                if bonjourDiscovery.discoveredGateways.isEmpty {
                    HStack {
                        if bonjourDiscovery.isSearching {
                            ProgressView().scaleEffect(0.7)
                            Text("Searching for OpenClaw gateways...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No gateways found on local network")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Search") {
                            bonjourDiscovery.startBrowsing()
                        }
                        .controlSize(.small)
                    }
                } else {
                    ForEach(bonjourDiscovery.discoveredGateways) { gw in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(gw.displayName)
                                    .fontWeight(.medium)
                                Text(gw.urlString)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Use") {
                                gatewayURL = gw.urlString
                                saveSettings()
                            }
                            .controlSize(.small)
                        }
                    }
                    Button("Search Again") {
                        bonjourDiscovery.startBrowsing()
                    }
                    .controlSize(.small)
                }
            }

            Section("System") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        LoginItemManager.shared.setEnabled(newValue)
                    }

                LabeledContent("Global Hotkey", value: "⌘J")
            }

            Section("About") {
                LabeledContent("Version", value: "1.0 (Phase 4)")
                LabeledContent("Build", value: "Polish & Integration")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 420)
        .onAppear {
            bonjourDiscovery.startBrowsing()
        }
        .onDisappear {
            bonjourDiscovery.stopBrowsing()
        }
    }

    private func saveSettings() {
        UserDefaults.standard.set(gatewayURL, forKey: "gatewayURL")
        appState.gatewayURL = gatewayURL
        try? KeychainHelper.shared.save(authToken, for: "gatewayToken")
    }

    private func testConnection() {
        isTestingConnection = true
        testResult = nil

        Task {
            let connected = await gatewayClient.checkConnection(gatewayURL: gatewayURL, token: authToken)
            await MainActor.run {
                isTestingConnection = false
                testResult = connected ? "✓ Connected" : "✗ Failed to connect"
                if connected {
                    appState.connectionState = .connected
                }
            }
        }
    }
}

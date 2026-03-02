import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var gatewayClient: GatewayHTTPClient

    @State private var gatewayURL: String = UserDefaults.standard.string(forKey: "gatewayURL") ?? "http://localhost:18789"
    @State private var authToken: String = (try? KeychainHelper.shared.get("gatewayToken")) ?? ""
    @State private var isTestingConnection = false
    @State private var testResult: String? = nil
    @State private var showToken = false

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
                        ProgressView()
                            .scaleEffect(0.7)
                    }

                    Spacer()

                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.hasPrefix("✓") ? Color.green : Color.red)
                    }
                }
            }

            Section("About") {
                LabeledContent("Version", value: "1.0 (Phase 1)")
                LabeledContent("Build", value: "Foundation / MVP")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 300)
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

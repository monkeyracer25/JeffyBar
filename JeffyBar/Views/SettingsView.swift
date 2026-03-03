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
    @State private var selectedModel: AIModel = {
        if let id = UserDefaults.standard.string(forKey: "selectedModel") {
            return AIModel.fromId(id)
        }
        return AIModel.default
    }()
    @State private var includeAppContext = UserDefaults.standard.object(forKey: "includeAppContext") as? Bool ?? true
    @State private var includeScreenshots = UserDefaults.standard.object(forKey: "includeScreenshots") as? Bool ?? true
    @State private var selectAndAskEnabled = UserDefaults.standard.object(forKey: "selectAndAskEnabled") as? Bool ?? true

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
                            .foregroundStyle(result.hasPrefix("\u{2713}") ? Color.green : Color.red)
                    }
                }
            }

            Section("Model & Context") {
                Picker("Default Model", selection: $selectedModel) {
                    ForEach(AIModel.allModels) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .onChange(of: selectedModel) { _, newValue in
                    appState.selectedModel = newValue
                }

                Toggle("Include App Context", isOn: $includeAppContext)
                    .onChange(of: includeAppContext) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "includeAppContext")
                    }
                Toggle("Include Screenshots", isOn: $includeScreenshots)
                    .onChange(of: includeScreenshots) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "includeScreenshots")
                    }
            }

            Section("Select & Ask") {
                HStack {
                    Text("Hotkey")
                    Spacer()
                    Text("\u{2325}+Space").font(.system(.body, design: .monospaced))
                }
                Toggle("Enabled", isOn: $selectAndAskEnabled)
                    .onChange(of: selectAndAskEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "selectAndAskEnabled")
                    }
            }

            Section("Accessibility") {
                if !AccessibilityManager.shared.hasPermission {
                    Button("Grant Accessibility Permission") {
                        AccessibilityManager.shared.requestPermission()
                    }
                } else {
                    Label("Accessibility: Granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
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
                    .onChange(of: launchAtLogin) { _, newValue in
                        LoginItemManager.shared.setEnabled(newValue)
                    }

                LabeledContent("Global Hotkey", value: "\u{2318}J")
            }

            Section("About") {
                LabeledContent("Version", value: "2.0 (Phase 2)")
                LabeledContent("Build", value: "Model Picker + Chat History + Context")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 600)
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
                testResult = connected ? "\u{2713} Connected" : "\u{2717} Failed to connect"
                if connected {
                    appState.connectionState = .connected
                }
            }
        }
    }
}

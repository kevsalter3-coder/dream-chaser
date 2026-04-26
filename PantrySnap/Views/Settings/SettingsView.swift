import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var households: [Household]

    @AppStorage("householdName")    private var householdName = "My Household"
    @AppStorage("defaultThreshold") private var defaultThreshold = 3.0
    @AppStorage("memberName")       private var memberName = ""

    @State private var instacartKey = ""
    @State private var keySaved     = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                // Household
                Section("Household") {
                    LabeledContent("Name") {
                        TextField("My Household", text: $householdName)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Your name") {
                        TextField("Optional", text: $memberName)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // Reorder settings
                Section("Reorder defaults") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Alert threshold")
                            Spacer()
                            Text("\(Int(defaultThreshold)) days remaining")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $defaultThreshold, in: 1...14, step: 1)
                            .accentColor(.accentColor)
                    }
                    .padding(.vertical, 4)
                }

                // Instacart API key
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        SecureField("Paste Instacart API key…", text: $instacartKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        HStack {
                            Button("Save key") { saveInstacartKey() }
                                .buttonStyle(.bordered)
                                .disabled(instacartKey.isEmpty)

                            if keySaved {
                                Label("Saved", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }

                            Spacer()

                            Button("Clear", role: .destructive) {
                                KeychainService.delete(key: Constants.Keychain.instacartAPIKey)
                                instacartKey = ""
                                keySaved = false
                            }
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Instacart API key")
                } footer: {
                    Text("Your key is stored securely in the iOS Keychain and never leaves this device.")
                }

                // Notifications
                Section("Notifications") {
                    Button("Request notification permission") {
                        Task { await NotificationService.shared.requestPermission() }
                    }
                }

                // Data management
                Section("Data") {
                    Button("Delete all pantry data", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }

                // About
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Open Food Facts", value: "openfoodfacts.org")
                    LabeledContent("Instacart API", value: "instacart.com/developer")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Delete all pantry data?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) { deleteAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
        .onAppear {
            if let existing = KeychainService.load(key: Constants.Keychain.instacartAPIKey) {
                instacartKey = existing
            }
        }
    }

    private func saveInstacartKey() {
        KeychainService.save(key: Constants.Keychain.instacartAPIKey, value: instacartKey)
        keySaved = true
    }

    private func deleteAllData() {
        try? context.delete(model: PantryItem.self)
        try? context.delete(model: Household.self)
        try? context.save()
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PantryItem.self, Household.self, configurations: config)
    return SettingsView().modelContainer(container)
}

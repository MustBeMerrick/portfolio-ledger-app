import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private var reportBugURL: URL {
        var components = URLComponents(string: "https://github.com/MustBeMerrick/portfolio-ledger-app/issues/new")!
        components.queryItems = [
            URLQueryItem(name: "title", value: "BUG: "),
            URLQueryItem(
                name: "body",
                value: """
                ## Summary

                ## Steps to Reproduce
                1.
                2.
                3.

                ## Expected Behavior

                ## Actual Behavior

                ## Environment
                - App version: \(appVersion)
                - Device:
                - OS version:

                ## Additional Context/Screenshots
                """
            )
        ]
        return components.url!
    }

    var body: some View {
        NavigationView {
            List {
                Section("Data") {
                    Button {
                        showingExportSheet = true
                    } label: {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showingImportSheet = true
                    } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
                    }
                }

                Section("Support") {
                    Link(destination: reportBugURL) {
                        Label("Report a Bug", systemImage: "ladybug")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }

                    Link("GitHub Repository", destination: URL(string: "https://github.com/MustBeMerrick/portfolio-ledger-app")!)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingExportSheet) {
                ExportView()
            }
            .sheet(isPresented: $showingImportSheet) {
                ImportView()
            }
        }
    }
}

struct ExportView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export all data to CSV files")
                    .font(.headline)

                Button("Export") {
                    // Export logic will be in CSVService
                    CSVService.shared.exportAll(dataStore: dataStore)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ImportView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Import data from CSV files")
                    .font(.headline)

                Button("Import") {
                    // Import logic will be in CSVService
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(DataStore.shared)
    }
}

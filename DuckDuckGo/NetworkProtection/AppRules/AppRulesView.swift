import SwiftUI

// Define a struct for the app representation
struct AppItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: String
    // Optional: Bundle Identifier or any other relevant info
    // let bundleIdentifier: String
}

struct AppRulesView: View {
    // State to manage the list of selected apps and all available apps
    @State private var selectedApps: [AppItem] = []
    @State private var allApps: [AppItem] = []
    @State private var newAppName: String = ""

    var body: some View {
        NavigationView {
            VStack {
                List {
                    // List all selected apps with a remove button
                    ForEach(selectedApps) { app in
                        HStack {
                            Text(app.name)
                            Spacer()
                            Button(action: {
                                removeApp(app: app)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }

                // HStack to add a new app by selecting from all apps
                HStack {
                    Picker("Add App", selection: $newAppName) {
                        ForEach(allApps.filter { !selectedApps.contains($0) }, id: \.name) { app in
                            Text(app.name).tag(app.name)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.leading, 16)

                    Button(action: {
                        addApp()
                    }) {
                        Image(systemName: "plus")
                            .padding(.trailing, 16)
                    }
                }
                .padding(.vertical, 10)
            }
            .navigationTitle("App List")
            .onAppear(perform: loadApps) // Load apps when the view appears
        }
    }

    // Function to remove app from the selected list
    private func removeApp(app: AppItem) {
        selectedApps.removeAll { $0 == app }
    }

    // Function to add a new app to the selected list
    private func addApp() {
        if let appToAdd = allApps.first(where: { $0.name == newAppName }) {
            selectedApps.append(appToAdd)
            newAppName = ""
        }
    }

    // Function to load apps from the /Applications directory
    private func loadApps() {
        let fileManager = FileManager.default
        let applicationsPath = "/Applications"

        do {
            let appURLs = try fileManager.contentsOfDirectory(atPath: applicationsPath)
                .filter { $0.hasSuffix(".app") }
                .map { applicationsPath + "/" + $0 }

            allApps = appURLs.map { appPath in
                let appName = appPath.components(separatedBy: "/").last ?? "Unknown"
                return AppItem(name: appName, path: appPath)
            }
        } catch {
            print("Failed to load applications: \(error.localizedDescription)")
        }
    }
}

struct AppListView_Previews: PreviewProvider {
    static var previews: some View {
        AppRulesView()
    }
}

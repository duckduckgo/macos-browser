//
//  DuckDuckGoVPN_tvOSApp.swift
//  DuckDuckGoVPN_tvOS
//
//  Created by ddg on 2/6/24.
//

import SwiftUI
import SwiftData

@main
struct DuckDuckGoVPN_tvOSApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

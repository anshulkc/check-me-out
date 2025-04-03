//
//  CheckMeOutApp.swift
//  CheckMeOut
//
//  Created by Anshul Chennavaram on 4/2/25.
//

import SwiftUI

@main
struct CheckMeOutApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

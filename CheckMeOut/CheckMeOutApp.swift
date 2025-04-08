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
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            ChallengesView()
                .tabItem {
                    Label("Challenges", systemImage: "trophy.fill")
                }
            
            Text("Leaderboard")
                .tabItem {
                    Label("Leaderboard", systemImage: "chart.bar.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .accentColor(.black)
    }
}

struct SettingsView: View {
    @AppStorage("userHeight") private var userHeight = 170.0 // cm
    @AppStorage("userWeight") private var userWeight = 70.0 // kg
    @AppStorage("userAge") private var userAge = 30
    @AppStorage("userGender") private var userGender = "Male"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    Picker("Gender", selection: $userGender) {
                        Text("Male").tag("Male")
                        Text("Female").tag("Female")
                        Text("Other").tag("Other")
                    }
                    
                    HStack {
                        Text("Age")
                        Spacer()
                        Stepper("\(userAge) years", value: $userAge, in: 18...100)
                    }
                    
                    HStack {
                        Text("Height")
                        Spacer()
                        Stepper(String(format: "%.1f cm", userHeight), value: $userHeight, in: 100...220, step: 0.5)
                    }
                    
                    HStack {
                        Text("Weight")
                        Spacer()
                        Stepper(String(format: "%.1f kg", userWeight), value: $userWeight, in: 30...200, step: 0.5)
                    }
                }
                
                Section(header: Text("Scan Settings")) {
                    Toggle("High Resolution Scan", isOn: .constant(true))
                    Toggle("Save Scan History", isOn: .constant(true))
                    Toggle("Show Detailed Results", isOn: .constant(true))
                }
                
                Section(header: Text("Privacy")) {
                    Toggle("Encrypt Scan Data", isOn: .constant(true))
                    Button("Delete All Scan Data") {
                        // Add confirmation dialog and deletion logic
                    }
                    .foregroundColor(.red)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                    
                    Button("Privacy Policy") {
                        // Open privacy policy
                    }
                    
                    Button("Terms of Service") {
                        // Open terms of service
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

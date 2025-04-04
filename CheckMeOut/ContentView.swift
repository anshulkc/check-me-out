//
//  ContentView.swift
//  CheckMeOut
//
//  Created by Anshul Chennavaram on 4/2/25.
//

import SwiftUI
import CoreData

// Define a model for our scan logs
struct ScanLog: Identifiable {
    let id = UUID()
    let timestamp: Date
    let bodyFatPercentage: Double
    let leanMusclePercentage: Double
    let visceralFatLevel: String
    let frontImageData: Data?
    let sideImageData: Data?
}

// Create a shared data model to store scan logs
class ScanLogStore: ObservableObject {
    @Published var scanLogs: [ScanLog] = []
    
    static let shared = ScanLogStore()
    
    func addScanLog(bodyFatPercentage: Double, leanMusclePercentage: Double, 
                   visceralFatLevel: String, frontImage: UIImage?, sideImage: UIImage?) {
        let frontImageData = frontImage?.jpegData(compressionQuality: 0.7)
        let sideImageData = sideImage?.jpegData(compressionQuality: 0.7)
        
        let newLog = ScanLog(
            timestamp: Date(),
            bodyFatPercentage: bodyFatPercentage,
            leanMusclePercentage: leanMusclePercentage,
            visceralFatLevel: visceralFatLevel,
            frontImageData: frontImageData,
            sideImageData: sideImageData
        )
        
        scanLogs.append(newLog)
    }
}

struct ContentView: View {
    @ObservedObject private var scanLogStore = ScanLogStore.shared
    
    var body: some View {
        NavigationView {
            List {
                ForEach(scanLogStore.scanLogs) { log in
                    NavigationLink {
                        ScanDetailView(log: log)
                    } label: {
                        ScanLogRow(log: log)
                    }
                }
            }
            .navigationTitle("Body Scan History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // For testing - add a sample log
                        #if DEBUG
                        scanLogStore.addScanLog(
                            bodyFatPercentage: Double.random(in: 10...30),
                            leanMusclePercentage: Double.random(in: 60...80),
                            visceralFatLevel: ["Low", "Medium", "High"].randomElement()!,
                            frontImage: nil,
                            sideImage: nil
                        )
                        #endif
                    }) {
                        Label("Add Sample", systemImage: "plus")
                    }
                }
            }
            
            Text("Select a scan to view details")
                .foregroundColor(.gray)
        }
    }
}

struct ScanLogRow: View {
    let log: ScanLog
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(log.timestamp, style: .date)
                    .font(.headline)
                Text(log.timestamp, style: .time)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Body Fat: \(String(format: "%.1f%%", log.bodyFatPercentage))")
                    .font(.subheadline)
                Text("Muscle: \(String(format: "%.1f%%", log.leanMusclePercentage))")
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ScanDetailView: View {
    let log: ScanLog
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Scan Results")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top)
                
                Group {
                    ResultRow(title: "Body Fat", value: String(format: "%.1f%%", log.bodyFatPercentage))
                    ResultRow(title: "Lean Muscle", value: String(format: "%.1f%%", log.leanMusclePercentage))
                    ResultRow(title: "Visceral Fat", value: log.visceralFatLevel)
                    ResultRow(title: "Scan Date", value: log.timestamp.formatted(date: .long, time: .shortened))
                }
                
                Text("Scan Images")
                    .font(.title2)
                    .bold()
                    .padding(.top)
                
                HStack {
                    VStack {
                        if let frontImageData = log.frontImageData, 
                           let uiImage = UIImage(data: frontImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(10)
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 200)
                                .overlay(
                                    Text("No front image")
                                        .foregroundColor(.gray)
                                )
                        }
                        Text("Front View")
                            .font(.caption)
                    }
                    
                    VStack {
                        if let sideImageData = log.sideImageData, 
                           let uiImage = UIImage(data: sideImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(10)
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 200)
                                .overlay(
                                    Text("No side image")
                                        .foregroundColor(.gray)
                                )
                        }
                        Text("Side View")
                            .font(.caption)
                    }
                }
            }
            .padding()
        }
    }
}

struct ResultRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(value)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}

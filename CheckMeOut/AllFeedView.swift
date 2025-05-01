//
//  AllFeedView.swift
//  CheckMeOut
//
//  Created to display all feed items
//

import SwiftUI

struct AllFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dataStore = AppDataStore.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                Text("All Feed Items")
                    .font(.tagesschriftTitle2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 12)
                
                if dataStore.feedItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No feed items yet")
                            .font(.tagesschriftSubheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    // Show all feed items
                    ForEach(dataStore.feedItems) { item in
                        FeedItemView(item: item)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .navigationTitle("All Feed")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AllFeedView()
    }
}

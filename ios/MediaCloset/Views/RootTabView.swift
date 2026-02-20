//
//  Views/RootTabView.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            RecordListView()
                .tabItem { Label("Records", systemImage: "opticaldisc") }

            CassetteListView()
                .tabItem { Label("Cassettes", systemImage: "cassette") }

            VHSListView()
                .tabItem { Label("VHS", systemImage: "film") }
            
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
        }
    }
}

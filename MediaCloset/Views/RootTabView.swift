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

            VHSListView()
                .tabItem { Label("VHS", systemImage: "film") }
            
            #if DEBUG
            SecretsTestView()
                .tabItem { Label("Debug", systemImage: "wrench.and.screwdriver") }
            #endif
        }
    }
}

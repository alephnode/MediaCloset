//
//  Views/Records/RecordListView.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
import SwiftUI

struct RecordListView: View {
    @StateObject var vm = RecordsVM()
    @State private var showNew = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.items) { item in
                    NavigationLink(value: item) {
                        HStack(spacing: 12) {
                            AsyncCover(url: item.coverUrl)
                            VStack(alignment: .leading) {
                                Text("\(item.artist)").font(.headline)
                                Text("\(item.album)").font(.subheadline)
                                Text([item.year?.description, item.colorVariants.isEmpty ? nil : item.colorVariants.joined(separator: ", ")]
                                     .compactMap { $0 }
                                     .joined(separator: " · "))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if !item.genres.isEmpty {
                                    Text(item.genres.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    Task {
                        for i in indexSet {
                            await vm.delete(id: vm.items[i].id)
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .onChange(of: searchText) { _, newValue in
                vm.search = newValue
                Task { await vm.load() }
            }
            .overlay { 
                if vm.isLoading { 
                    ProgressView() 
                } else if let errorMessage = vm.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Connection Error")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            Task { await vm.load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("Records")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: { Image(systemName: "plus") }
                }
            }
            .navigationDestination(for: RecordListItem.self) { item in
                RecordDetailView(recordId: item.id)
            }
        }
        .sheet(isPresented: $showNew) {
            RecordFormView { Task { await vm.load() } }
        }
        .task { await vm.load() }
        
    }
}




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
                                Text([item.year?.description, item.colorVariant]
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
            .onSubmit(of: .search) {
                vm.search = searchText
                Task { await vm.load() }
            }
            .overlay { if vm.isLoading { ProgressView() } }
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




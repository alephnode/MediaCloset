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
                    .onAppear {
                        if vm.shouldLoadMore(currentItem: item) {
                            Task { await vm.loadMore() }
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

                // Loading indicator at bottom
                if vm.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .refreshable {
                await vm.loadInitial()
            }
            .searchable(text: $searchText)
            .onChange(of: searchText) { _, newValue in
                vm.search = newValue
                vm.searchChanged()
            }
            .overlay {
                if vm.isLoading && vm.items.isEmpty {
                    ProgressView()
                } else if let errorMessage = vm.errorMessage, vm.items.isEmpty {
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
                } else if vm.items.isEmpty && !vm.isLoading {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Albums" : "No Results",
                        systemImage: searchText.isEmpty ? "music.note.list" : "magnifyingglass",
                        description: Text(searchText.isEmpty ? "Add your first album to get started." : "Try a different search term.")
                    )
                }
            }
            .navigationTitle("Records")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort By", selection: Binding(
                            get: { vm.sortField },
                            set: { newValue in
                                vm.sortField = newValue
                                vm.sortChanged()
                            }
                        )) {
                            Label("Date Added", systemImage: "calendar").tag(SortField.createdAt)
                            Label("Artist", systemImage: "person").tag(SortField.artist)
                            Label("Title", systemImage: "textformat").tag(SortField.title)
                        }
                        Divider()
                        Picker("Order", selection: Binding(
                            get: { vm.sortOrder },
                            set: { newValue in
                                vm.sortOrder = newValue
                                vm.sortChanged()
                            }
                        )) {
                            Label("Descending", systemImage: "arrow.down").tag(SortOrder.desc)
                            Label("Ascending", systemImage: "arrow.up").tag(SortOrder.asc)
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
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

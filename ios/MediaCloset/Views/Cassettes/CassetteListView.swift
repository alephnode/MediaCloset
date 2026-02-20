//
//  Views/Cassettes/CassetteListView.swift
//  MediaCloset
//
import SwiftUI

struct CassetteListView: View {
    @StateObject var vm = CassettesVM()
    @State private var showNew = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                if vm.isLoading && vm.items.isEmpty {
                    ForEach(0..<8, id: \.self) { index in
                        SkeletonCassetteRow(index: index)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(vm.items) { item in
                        NavigationLink(value: item) {
                            HStack(spacing: 12) {
                                AsyncCover(url: item.coverUrl)
                                VStack(alignment: .leading) {
                                    Text(item.artist).font(.headline)
                                    Text(item.album).font(.subheadline)
                                    HStack(spacing: 4) {
                                        if let year = item.year {
                                            Text(year.description)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        if let tapeType = item.tapeType, !tapeType.isEmpty {
                                            if item.year != nil {
                                                Text("·")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Text(tapeType)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
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
            }
            .animation(.default, value: vm.items.isEmpty)
            .refreshable {
                await vm.refresh()
            }
            .searchable(text: $searchText)
            .onChange(of: searchText) { _, newValue in
                vm.search = newValue
                vm.searchChanged()
            }
            .overlay {
                if let errorMessage = vm.errorMessage, vm.items.isEmpty {
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
                        searchText.isEmpty ? "No Cassettes" : "No Results",
                        systemImage: searchText.isEmpty ? "cassette" : "magnifyingglass",
                        description: Text(searchText.isEmpty ? "Add your first cassette to get started." : "Try a different search term.")
                    )
                }
            }
            .navigationTitle("Cassettes")
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
            .navigationDestination(for: CassetteListItem.self) { item in
                CassetteDetailView(cassetteId: item.id)
            }
        }
        .sheet(isPresented: $showNew) {
            CassetteFormView { Task { await vm.load() } }
        }
        .task { await vm.load() }
    }
}

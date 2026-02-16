//
//  Views/VHS/VHSListView.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
import SwiftUI

struct VHSListView: View {
    @StateObject var vm = VHSVM()
    @State private var showNew = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                if vm.isLoading && vm.items.isEmpty {
                    // Skeleton loading state
                    ForEach(0..<8, id: \.self) { index in
                        SkeletonVHSRow(index: index)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(vm.items) { item in
                        NavigationLink(value: item) {
                            HStack(spacing: 12) {
                                AsyncCover(url: item.coverUrl)
                                VStack(alignment: .leading) {
                                    Text(item.title).font(.headline)
                                    Text([
                                        (item.director?.isEmpty == false ? item.director : nil),
                                        item.year.map(String.init),
                                        item.genre
                                    ].compactMap { $0 }.joined(separator: " · "))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
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
                            for i in indexSet { await vm.delete(id: vm.items[i].id) }
                        }
                    }

                    // Loading indicator at bottom for infinite scroll
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
                        searchText.isEmpty ? "No Movies" : "No Results",
                        systemImage: searchText.isEmpty ? "film" : "magnifyingglass",
                        description: Text(searchText.isEmpty ? "Add your first movie to get started." : "Try a different search term.")
                    )
                }
            }
            .navigationTitle("VHS")
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
            .navigationDestination(for: VHSListItem.self) { item in
                VHSDetailView(vhsId: item.id)
            }
            .sheet(isPresented: $showNew) {
                VHSFormView { Task { await vm.load() } }
            }
            .task { await vm.load() }
        }
    }
}

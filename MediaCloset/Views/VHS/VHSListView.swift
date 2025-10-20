//
//  Views/VHS/VHSListView.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
// VHSListView.swift
import SwiftUI

struct VHSListView: View {
    @StateObject var vm = VHSVM()
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
                }
                .onDelete { indexSet in
                    Task {
                        for i in indexSet { await vm.delete(id: vm.items[i].id) }
                    }
                }
            }
            .searchable(text: $searchText)
            .onChange(of: searchText) { _, newValue in
                vm.search = newValue
            }
            .onSubmit(of: .search) {
                Task { await vm.load() }
            }
            .overlay { if vm.isLoading { ProgressView() } }
            .navigationTitle("VHS")
            .toolbar {
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

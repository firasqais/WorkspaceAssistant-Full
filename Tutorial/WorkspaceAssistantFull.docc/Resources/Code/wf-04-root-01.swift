import SwiftUI

/// The app's root: a tab bar with Tasks, Collections and Search.
struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(BoardViewModel.self) private var board
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        @Bindable var router = router
        @Bindable var board = board
        TabView(selection: $router.tab) {
            Tab(value: AppTab.tasks) {
                BoardScreen(collection: .all)
            } label: {
                Label { Text("Tasks") } icon: { Image(systemName: "square.grid.2x2") }
            }

            Tab(value: AppTab.collections) {
                CollectionsScreen()
            } label: {
                Label { Text("Collections") } icon: { Image(systemName: "folder") }
            }

            Tab(value: AppTab.search, role: .search) {
                SearchScreen(query: $router.searchQuery)
            } label: {
                Label { Text("Search") } icon: { Image(systemName: "magnifyingglass") }
            }
        }
        .boardPresentations()
        .tint(board.store.preferences.accent.color)
        .onAppear { board.store.undoManager = undoManager }
        .onChange(of: undoManager) { _, manager in board.store.undoManager = manager }
    }
}

import SwiftUI

@main
struct SheetBinding_BugApp: App {
  var body: some Scene {
    WindowGroup {
      AppView(
        store: .init(
          initialState: Todos.State(todos: .mock),
          reducer: Todos()
        )
      )
    }
  }
}

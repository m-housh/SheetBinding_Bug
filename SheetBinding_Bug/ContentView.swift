import ComposableArchitecture
import SwiftUI

struct Todos: Reducer {
  struct State: Equatable {
    var editMode: EditMode = .inactive
    var todos: IdentifiedArrayOf<Todo.State> = []
    @PresentationState var addTodo: Todo.State? = nil
  }

  enum Action: Equatable {
    case addTodoButtonTapped
    case addTodo(PresentationAction<Todo.Action>)
    case clearCompletedButtonTapped
    case delete(IndexSet)
    case editModeChanged(EditMode)
    case move(IndexSet, Int)
    case recieveTodo(Todo.State)
    case saveTodoButtonTapped
    case sortCompletedTodos
    case todo(id: Todo.State.ID, action: Todo.Action)
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.uuid) var uuid
  private enum TodoCompletionID {}

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .addTodoButtonTapped:
        state.addTodo = Todo.State(id: self.uuid())
        return .none

      case .addTodo(.dismiss):
        state.addTodo = nil
        return .none

      case .addTodo:
        return .none

      case .clearCompletedButtonTapped:
        state.todos.removeAll(where: \.isComplete)
        return .none

      case let .delete(indexSet):
        state.todos.remove(atOffsets: indexSet)
        return .none

      case let .editModeChanged(editMode):
        state.editMode = editMode
        return .none

      case let .move(source, destination):
        state.todos.move(fromOffsets: source, toOffset: destination)
        return .task {
          try await self.clock.sleep(for: .milliseconds(100))
          return .sortCompletedTodos
        }

      case .recieveTodo(let todo):
        state.todos.insert(todo, at: 0)
        state.addTodo = nil
        return .none

      case .saveTodoButtonTapped:
        guard let addTodo = state.addTodo else { return .none }
        // similate saving to disk / database.
        return .task { [addTodo = addTodo] in
          try await self.clock.sleep(for: .milliseconds(100))
          return .recieveTodo(addTodo)
        }

      case .sortCompletedTodos:
        state.todos.sort { $1.isComplete && !$0.isComplete }
        return .none

      case .todo(id: _, action: .binding(\.$isComplete)):
        return .run { send in
          try await self.clock.sleep(for: .seconds(1))
          await send(.sortCompletedTodos, animation: .default)
        }
        .cancellable(id: TodoCompletionID.self, cancelInFlight: true)

      case .todo:
        return .none
      }
    }
    .forEach(\.todos, action: /Action.todo(id:action:)) {
      Todo()
    }
    .ifLet(\.$addTodo, action: /Action.addTodo) {
      Todo()
    }
  }
}

struct AppView: View {
  let store: StoreOf<Todos>
  @ObservedObject var viewStore: ViewStore<ViewState, Todos.Action>

  init(store: StoreOf<Todos>) {
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init(state:)))
  }

  struct ViewState: Equatable {
    let editMode: EditMode
    let isClearCompletedButtonDisabled: Bool

    init(state: Todos.State) {
      self.editMode = state.editMode
      self.isClearCompletedButtonDisabled = !state.todos.contains(where: \.isComplete)
    }
  }

  var body: some View {
    NavigationView {
      VStack(alignment: .leading) {
        List {
          ForEachStore(
            self.store.scope(state: \.todos, action: Todos.Action.todo(id:action:))
          ) {
            TodoView(store: $0)
          }
          .onDelete { self.viewStore.send(.delete($0)) }
          .onMove { self.viewStore.send(.move($0, $1)) }
        }
      }
      .navigationTitle("Todos")
      .navigationBarItems(
        trailing: HStack(spacing: 20) {
          EditButton()
          Button("Clear Completed") {
            self.viewStore.send(.clearCompletedButtonTapped, animation: .default)
          }
          .disabled(self.viewStore.isClearCompletedButtonDisabled)
          Button("Add Todo") { self.viewStore.send(.addTodoButtonTapped, animation: .default) }
        }
      )
      .environment(
        \.editMode,
         self.viewStore.binding(get: \.editMode, send: Todos.Action.editModeChanged)
      )
      .sheet(
        store: store.scope(state: \.$addTodo, action: Todos.Action.addTodo)
      ) { todoStore in
        NavigationView {
          TodoView(store: todoStore)
            .navigationTitle("Add Todo")
            .toolbar {
              ToolbarItem(placement: .confirmationAction) {
                Button(action: { viewStore.send(.saveTodoButtonTapped) }) {
                  Text("Save")
                }
              }
              ToolbarItem(placement: .cancellationAction) {
                Button(action: { viewStore.send(.addTodo(.dismiss)) }) {
                  Text("Cancel")
                }
              }
            }
        }
      }
    }
    .navigationViewStyle(.stack)
  }
}

extension IdentifiedArray where ID == Todo.State.ID, Element == Todo.State {
  static let mock: Self = [
    Todo.State(
      description: "Check Mail",
      id: UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEDDEADBEEF")!,
      isComplete: false
    ),
    Todo.State(
      description: "Buy Milk",
      id: UUID(uuidString: "CAFEBEEF-CAFE-BEEF-CAFE-BEEFCAFEBEEF")!,
      isComplete: false
    ),
    Todo.State(
      description: "Call Mom",
      id: UUID(uuidString: "D00DCAFE-D00D-CAFE-D00D-CAFED00DCAFE")!,
      isComplete: true
    ),
  ]
}

struct AppView_Previews: PreviewProvider {
  static var previews: some View {
    AppView(
      store: Store(
        initialState: Todos.State(todos: .mock),
        reducer: Todos()
      )
    )
  }
}

import ComposableArchitecture
import SwiftUI

struct Todo: Reducer {
  struct State: Equatable, Identifiable {
    @BindingState var description = ""
    let id: UUID
    @BindingState var isComplete = false
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
  }

  var body: some ReducerProtocolOf<Self> {
    BindingReducer()
  }

}

struct TodoView: View {
  let store: StoreOf<Todo>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      HStack {
        Button(action: { viewStore.send(.set(\.$isComplete, viewStore.isComplete ? false : true)) }) {
          Image(systemName: viewStore.isComplete ? "checkmark.square" : "square")
        }
        .buttonStyle(.plain)

        TextField(
          "Untitled Todo",
          text: viewStore.binding(\.$description)
        )
      }
      .foregroundColor(viewStore.isComplete ? .gray : nil)
    }
  }
}

import Foundation
import Combine

/// Represents a holder of `Store`.
@MainActor
public final class KeemunConnector<ViewState: Sendable, ExternalMsg: Sendable>: ObservableObject {
    /// Current state for user view.
    @Published public private(set) var state: ViewState

    private var dispatch: @Sendable (ExternalMsg) -> Void
    private var cancellable: Set<AnyCancellable> = []

    public init<State: Sendable, Msg: Sendable, Effect: Sendable>(
            store: Store<State, Msg, Effect>,
            featureParams: FeatureParams<State, Msg, ViewState, ExternalMsg>
    ) async {
        // 1) получаем initial state (await допускается, т.к. init async)
        let initial = await store.getCurrentStateValue()
        // 2) инициализируем ВСЕ stored props до любых Task/closure
        self.state = featureParams.viewStateTransform.transform(initial)
        self.dispatch = { msg in
            Task {
                await store.dispatchMessage(featureParams.messageTransform(msg))
            }
        }

        // 3) запускаем наблюдение уже после инициализации
        Task { [weak self] in
            guard let self else { return }
            let stream = await store.stateStream()
            for await newState in stream {
                // мы уже @MainActor, можно писать напрямую
                self.state = featureParams.viewStateTransform.transform(newState)
            }
        }
    }

    func observeStateChanges<State: Sendable, Msg: Sendable, Effect: Sendable>(
        store: Store<State, Msg, Effect>,
        featureParams: FeatureParams<State, Msg, ViewState, ExternalMsg>
    ) async {        
        let stateStrem = await store.stateStream()
        Task {
            for await newState in stateStrem {
                await transformStateForViewState(featureParams: featureParams, state: newState)
            }
        }
    }

    func transformStateForViewState<State, Msg>(
        featureParams: FeatureParams<State, Msg, ViewState, ExternalMsg>,
        state: State
    ) async {
        self.state = featureParams.viewStateTransform.transform(state)
    }

    /// Sending messages asynchronously.
    public func dispatch(_ msg: ExternalMsg) {
        dispatch(msg)
    }
}

public extension KeemunConnector {
    convenience init<State: Sendable, Msg: Sendable, Effect: Sendable>(
        storeParams: StoreParams<State, Msg, Effect>,
        featureParams: FeatureParams<State, Msg, ViewState, ExternalMsg>
    ) async {
        await self.init(store: Store(storeParams), featureParams: featureParams)
    }
}

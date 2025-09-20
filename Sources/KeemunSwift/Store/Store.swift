import Foundation
import Combine

/// The entity controls all entities and initiates the message processing and side effect mechanism.
public final actor Store<State: Sendable, Msg: Sendable, Effect: Sendable>: Sendable {
    private let params: StoreParams<State, Msg, Effect>

    private let _state: CurrentValueSubject<State, Never>

    private let _messages = PassthroughSubject<Msg, Never>()
    private var cancellables: Set<AnyCancellable> = []

    public var currentState: State { self._state.value }
    public let state: AnyPublisher<State, Never>
    private let relay = AsyncRelay<State>()

    public init(_ params: StoreParams<State, Msg, Effect>) {
        self.params = params

        let startNext = self.params.start.run()
        let defaultState = startNext.state
        let startEffects = startNext.effects

        self._state = CurrentValueSubject(defaultState)
        self.state = self._state.eraseToAnyPublisher()

        Task {
            await self.startObserveMessages()
            await self.effectProcess(startEffects, dispatch: self.dispatch)
        }
    }

    /// Sending messages asynchronously.
    public lazy var dispatch: Dispatch<Msg> = { [weak self] msg in
        guard let self else { return }
        Task {
            await sendMessage(msg)
        }
    }

    private func startObserveMessages() async {
        let observeMessagesQueue = DispatchQueue(label: "keemun.observeMessagesQueue", qos: .userInitiated)
        self._messages
            .receive(on: observeMessagesQueue)
            .buffer(size: .max, prefetch: .keepFull, whenFull: .dropOldest)
            .sink { [weak self] msg in
                guard let self else { return }
                Task {
                    await handleMesssage(msg)
                }
            }
            .store(in: &self.cancellables)
    }

    // MARK: - Current state
    func getCurrentStateValue() async -> State {
        return currentState
    }

    func stateStream () async -> AsyncStream<State> {
        await relay.stream()
    }

    // MARK: - Messages

    func dispatchMessage(_ msg: Msg) {
        Task {
            await sendMessage(msg)
        }
    }

    private func sendMessage(_ msg: Msg) async {
        _messages.send(msg)
    }

    private func handleMesssage(_ msg: Msg) async {
        await observeMessages(state: _state.value, msg: msg)
    }

    private func observeMessages(state: State, msg: Msg) async {
        let next = self.params.update.run(msg, state)
        self._state.send(next.state)
        await self.relay.send(next.state)

        await effectProcess(next.effects, dispatch: self.dispatch)
    }

    private func effectProcess(_ effects: [Effect], dispatch: @escaping Dispatch<Msg>) async {
        for effectHandler in self.params.effectHandlers {
            for effect in effects {
                switch effectHandler.processing(effect) {
                case let .publisher(anyPublisher):
                    anyPublisher
                        .sink { msg in
                            dispatch(msg)
                        }
                        .store(in: &cancellables)

                case let .task(priority, operation):
                    Task(priority: priority) {
                        await operation { msg in
                            dispatch(msg)
                        }
                    }
                }
            }
        }
    }
}


/// Потокобезопасный ретранслятор значений в виде AsyncStream (Sendable).
actor AsyncRelay<T: Sendable> {
    private var continuations: [UUID: AsyncStream<T>.Continuation] = [:]
    private var last: T?

    func stream(replayLatest: Bool = true) -> AsyncStream<T> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation

            if replayLatest, let last { continuation.yield(last) }

            continuation.onTermination = { @Sendable [weak self] _ in
                // Удаляем continuation из реестра
                Task { await self?.remove(id) }
            }
        }
    }

    func send(_ value: T) {
        last = value
        for c in continuations.values { c.yield(value) }
    }

    func finish() {
        for c in continuations.values { c.finish() }
        continuations.removeAll()
    }

    private func remove(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}

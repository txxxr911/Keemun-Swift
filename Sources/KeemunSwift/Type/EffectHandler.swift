import Combine
import Dispatch
import Foundation

public typealias Dispatch<Msg> = @Sendable (Msg) -> Void

public struct EffectHandler<Effect, Msg>: Sendable {
    public let processing: @Sendable (Effect) -> Operation<Msg>

    public init(_ processing: @Sendable @escaping (Effect) -> Operation<Msg>) {
        self.processing = processing
    }
    
    public enum Operation<Message> {
        case publisher(AnyPublisher<Message, Never>)
        case task(TaskPriority? = nil, @Sendable (Dispatch<Msg>) async -> Void)
    }
}

public extension EffectHandler {
    func map<OutMsg>(_ transform: @Sendable @escaping (Msg) -> OutMsg) -> EffectHandler<Effect, OutMsg> {
        return EffectHandler<Effect, OutMsg> { effect in
            switch self.processing(effect) {
            case let .publisher(anyPublisher):
                return .publisher(
                    anyPublisher
                        .map(transform)
                        .eraseToAnyPublisher()
                )
                
            case let .task(priority, operation):
                return .task(priority) { dispatch in
                    await operation { msg in dispatch(transform(msg))}
                }
            }
        }
    }
}

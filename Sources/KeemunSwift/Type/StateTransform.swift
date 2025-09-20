import Foundation
import Dispatch

public struct StateTransform<State, OutState>: Sendable {
    public let transform: @Sendable (State) -> OutState

    public init(_ transform: @Sendable @escaping (State) -> OutState) {
        self.transform = transform
    }
}

import Foundation

public struct Update<State, Msg, Effect>: Sendable {
    public let run: @Sendable (Msg, State) -> Next<State, Effect>
    
    public init(_ run: @Sendable @escaping (Msg, State) -> Next<State, Effect>) {
        self.run = run
    }
}

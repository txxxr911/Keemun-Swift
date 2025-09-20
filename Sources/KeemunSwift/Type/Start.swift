import Foundation

public struct Start<State, Effect>: Sendable {
    public let run: @Sendable () -> Next<State, Effect>

    public init(_ run: @Sendable @escaping () -> Next<State, Effect>) {
        self.run = run
    }
}

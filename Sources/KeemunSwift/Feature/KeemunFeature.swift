import Foundation

public protocol KeemunFeature<State, Msg, Effect, ViewState, ExternalMsg> {
    associatedtype State
    associatedtype Msg
    associatedtype Effect
    associatedtype ViewState = State
    associatedtype ExternalMsg = Msg
    
    var storeParams: StoreParams<State, Msg, Effect> { get }
    var featureParams: FeatureParams<State, Msg, ViewState, ExternalMsg> { get }
}

public extension KeemunConnector {
    convenience init<State: Sendable, Msg: Sendable, Effect: Sendable>(
        _ feature: some KeemunFeature<State, Msg, Effect, ViewState, ExternalMsg>
    ) async {
        await self.init(storeParams: feature.storeParams, featureParams: feature.featureParams)
    }
}

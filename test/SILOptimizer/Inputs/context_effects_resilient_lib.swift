@_spi(ExperimentalContextEffects) import Swift

// Resilient effects(E) forwarder: its body is unavailable to clients, so the call cannot specialize
// across the module boundary and must pass runtime metadata.
@_spi(ExperimentalContextEffects)
public func resilientForward<T, E: Effect>(_ x: borrowing T, _ body: () effects(E) -> Void) effects(E) {
  body()
}

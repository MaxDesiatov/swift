@_spi(ExperimentalContextEffects) import Swift

// A polymorphic effects(E) row that must survive binary serialization: the
// deserialized variable row has to resolve against the deserialized generic
// signature and drive cross-module inference/enforcement.
@_spi(ExperimentalContextEffects)
public func forward<Result, E: Effect>(_ body: () effects(E) -> Result) effects(E) -> Result { body() }

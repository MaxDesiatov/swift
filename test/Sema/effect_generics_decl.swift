// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects
// REQUIRES: swift_feature_ContextEffects
protocol FileSystem: Effect { mutating func read() -> String }

// Effect variable, explicitly constrained: no diagnostics.
func forward<E: Effect>(_ body: () effects(E) -> Void) effects(E) { body() }

// Unconstrained E: the bound E: Effect is inferred, so this is not an error
// (like throws(E) inferring E: Error).
func inferred<E>(_ body: () effects(E) -> Void) {}

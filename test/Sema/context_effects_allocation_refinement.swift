// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects
// REQUIRES: swift_feature_ContextEffects

// Allocation refines Locking: an Allocation context may call a Locking callee, but
// a Locking context may not call an Allocation callee.

@_spi(ExperimentalContextEffects) import Swift

func lockingCallee() effects(Locking) {}
func allocCallee() effects(Allocation) {} // expected-note {{declared here}}

func allocCallsLocking() effects(Allocation) { lockingCallee() }
func allocCallsAlloc() effects(Allocation) { allocCallee() }

func lockingCallsAlloc() effects(Locking) {
  allocCallee() // expected-error {{call to function that has effects 'Allocation' is not allowed; enclosing function only has effects 'Locking'}}
}

// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects
// REQUIRES: swift_feature_ContextEffects

protocol Allocation: Locking {}
protocol Networking: Effect {}
protocol HTTPNetworking: Networking {}

func lockingCallee() effects(Locking) {}
func allocCallee() effects(Allocation) {} // expected-note {{declared here}}
func net() effects(Networking) {}
func http() effects(HTTPNetworking) {} // expected-note {{declared here}}

// A refined context permits a call to its parent effect (callee does a subset).
func allocCallsLocking() effects(Allocation) { lockingCallee() }
func httpCallsNet() effects(HTTPNetworking) { net() }

func allocCallsAlloc() effects(Allocation) { allocCallee() }

// Parent context cannot call a refined callee.
func lockingCallsAlloc() effects(Locking) {
  allocCallee() // expected-error {{call to function that has effects 'Allocation' is not allowed; enclosing function only has effects 'Locking'}}
}
func netCallsHTTP() effects(Networking) {
  http() // expected-error {{call to function that has effects 'HTTPNetworking' is not allowed; enclosing function only has effects 'Networking'}}
}

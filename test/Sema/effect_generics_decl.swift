// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects
// REQUIRES: swift_feature_ContextEffects
protocol FileSystem: Effect { mutating func read() -> String }

// Effect variable, explicitly constrained: no diagnostics.
func forward<E: Effect>(_ body: () effects(E) -> Void) effects(E) { body() }

// Unconstrained E: the bound E: Effect is inferred, so this is not an error
// (like throws(E) inferring E: Error).
func inferred<E>(_ body: () effects(E) -> Void) {}

protocol A: Effect {}

// A variable effects row as the final signature token (no explicit result type)
// must resolve E; before the fix this reported 'cannot find type E in scope'.
protocol ForwardingReq {
  func run<E: Effect>(_ body: () effects(E) -> Void) effects(E)
  init<E: Effect>(_ body: () effects(E) -> Void) effects(E)
}

// Explicit result type was the pre-fix workaround; keep it working.
protocol ForwardingReqExplicit {
  func run<E: Effect>(_ body: () effects(E) -> Void) effects(E) -> Void
}

// All signature terms present (effects first, then async/typed-throws), implicit
// result: both the effects variable E and the thrown-error variable Err resolve.
protocol ForwardingReqFull {
  func run<E: Effect, Err: Error>(_ body: () effects(E) -> Void) effects(E) async throws(Err)
}

// Accessor requirement carrying an effects row over an associated effect type:
// exercises the shared AbstractFunctionDecl signature-range path for AccessorDecl.
protocol HasEffectAccessor {
  associatedtype E: Effect
  var x: Int { get effects(E) }
}

// Known limitation: a variable member in an effect-row composition is resolved as
// a protocol-composition type, which forbids a type parameter as a member. This
// fails independently of the source range (also with an explicit result / a body);
// admitting E here needs a dedicated effect-row-union resolution path (future work).
protocol ForwardingReqComposed {
  func runComposed<E: Effect>(_ body: () effects(E) -> Void) effects(E & A)
  // expected-error@-1 {{non-protocol, non-class type 'E' cannot be used within a protocol-constrained type}}
}

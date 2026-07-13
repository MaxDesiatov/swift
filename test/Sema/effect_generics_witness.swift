// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects
// REQUIRES: swift_feature_ContextEffects

// The requirement uses the natural Void-returning spelling, which only type-checks
// after the signature-range fix (a generic effects row as the final token).
protocol Forwarding {
  func run<E: Effect>(_ body: () effects(E) -> Void) effects(E)
  // expected-note@-1 {{protocol requires function 'run' with type '<E> (() effects(E) -> Void) effects(E) -> ()'}}
}

// Exact variable row: conforms.
struct Good: Forwarding {
  func run<E: Effect>(_ body: () effects(E) -> Void) effects(E) { body() }
}

// Tighter (bottom) row: Never <: E, so it conforms (mirrors typed throws).
struct NeverWit: Forwarding {
  func run<E: Effect>(_ body: () effects(E) -> Void) effects(Never) { }
}

// Looser (absent = top) row: not <: E, so it is rejected.
struct AbsentWit: Forwarding { // expected-error {{type 'AbsentWit' does not conform to protocol 'Forwarding'}}
  // expected-note@-1 {{add stubs for conformance}}
  func run<E: Effect>(_ body: () effects(E) -> Void) { }
  // expected-note@-1 {{candidate does not satisfy effects('E') effect restriction of protocol requirement}}
}

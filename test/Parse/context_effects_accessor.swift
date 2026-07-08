// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects
// REQUIRES: swift_feature_ContextEffects

// The legacy C++ parser must accept an `effects(...)` clause on a `get`
// accessor (the stdlib Availability migration needs it) and reject it on other
// accessors with a clean diagnostic, not a cascading "expected '{'".

struct ConcreteGetter {
  // The migration's required case: a concrete property getter.
  var x: Int {
    get effects(Never) { 0 }
  }
}

protocol ProtocolGetter {
  // Protocol-property requirement getter (limited syntax, no body).
  var y: Int { get effects(Never) }
}

struct NonGetAccessor {
  var stored: Int = 0
  var z: Int {
    get { stored }
    set effects(Never) { stored = newValue } // expected-error {{'set' accessor cannot have specifier 'effects'}}
  }
}

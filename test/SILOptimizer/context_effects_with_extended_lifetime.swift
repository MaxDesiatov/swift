// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s -o /dev/null -verify
// REQUIRES: optimized_stdlib
// REQUIRES: swift_feature_ContextEffects

// XFAIL: *

class C {}

func withExtendedLifetime<
  T: ~Copyable & ~Escapable,
  Eff: Effect,
  Failure: Error,
  Result: ~Copyable
>(
  _ x: borrowing T,
  _ body: () effects(Eff) throws(Failure) -> Result
) effects(Eff) throws(Failure) -> Result {
  defer { extendLifetime(x) }
  return try body()
}


func neverCaller(_ c: C) effects(Never) -> C {
  return withExtendedLifetime(c) { () effects(Never) in
    return c // expected-error {{this code performs reference counting operations which can cause locking}}
  }
}


func lockingCaller(_ c: C) effects(Locking) -> C {
  return withExtendedLifetime(c) { () effects(Locking) in
    return c
  }
}

// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s -o /dev/null -verify
// REQUIRES: optimized_stdlib
// REQUIRES: swift_feature_ContextEffects

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
  return withExtendedLifetime(c) { () effects(Never) in // expected-error {{this code performs reference counting operations which can cause locking}}
    return c
  }
}


func lockingCaller(_ c: C) effects(Locking) -> C {
  return withExtendedLifetime(c) { () effects(Locking) in
    return c
  } // expected-error {{ending the lifetime of a value of type 'C' can cause a deallocation}}
}


func allocationCaller(_ c: C) effects(Allocation) -> C {
  return withExtendedLifetime(c) { () effects(Allocation) in
    return c
  }
}


// Specialization is keyed on the substituted Eff, not the caller's effect: a stricter
// closure effect is enforced on the passed closure regardless of the caller's effect.

func allocationCallerLockingClosure(_ c: C) effects(Allocation) -> C {
  return withExtendedLifetime(c) { () effects(Locking) in
    return c
  }
}


func allocationCallerNeverClosure(_ c: C) effects(Allocation) -> C {
  return withExtendedLifetime(c) { () effects(Never) in // expected-note {{called from here}}
    return c // expected-error {{this code performs reference counting operations which can cause locking}}
  }
}

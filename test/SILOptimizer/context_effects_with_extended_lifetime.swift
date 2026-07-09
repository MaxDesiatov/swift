// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s -o /dev/null -verify
// REQUIRES: optimized_stdlib
// REQUIRES: swift_feature_ContextEffects

// Effect generics are not implemented yet (plan Phases 1-3: a variable effect row does not
// resolve, bind at the call site, or forward through the SIL performance firewall). Today
// effects(Eff) resolves to the empty set, so Eff never binds to Never and the NoLocks
// enforcement below never fires. Un-XFAIL when effect-variable forwarding lands; an XPASS
// here is the tripwire that it has.
// XFAIL: *

class C {}

// A withExtendedLifetime-shaped pure forwarder generic over an effect variable Eff. This is
// the payoff of effect generics that @_noLocks / @_noAllocation cannot express: those
// attributes are not part of the function type, so a wrapper cannot say "I am NoLocks iff my
// closure is." The own body is a pure forwarder (extendLifetime is a no-op builtin), so it
// passes under the strongest binding; the forwarded closure carries the real effect. The
// effects(Eff) row runs parallel to the throws(Failure) row the stdlib function already has.
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

// Pure closure => Eff := Never => the forwarded call is enforced NoLocks. Retaining a class
// value in the closure's own NoLocks body is the diagnostic, and it lands at the closure
// literal rather than inside the forwarder (which trusts the forwarded apply).
func neverCaller(_ c: C) effects(Never) -> C {
  return withExtendedLifetime(c) {
    () effects(Never) in
    return c // expected-error {{this code performs reference counting operations which can cause locking}}
  }
}

// Locking closure => Eff := Locking => the forwarded call is enforced NoAllocation, which
// permits ARC. Same retain, no diagnostic: the substituted constraint governs the call site,
// not a blanket NoLocks. This binding-dependent enforcement is exactly what a fixed attribute
// cannot do.
func lockingCaller(_ c: C) effects(Locking) -> C {
  return withExtendedLifetime(c) {
    () effects(Locking) in
    return c
  }
}

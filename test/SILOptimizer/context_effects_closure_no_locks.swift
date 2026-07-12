// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s -o /dev/null -verify
// REQUIRES: optimized_stdlib
// REQUIRES: swift_feature_ContextEffects

// End-to-end: a clause-less closure argument infers E := Never and the resulting program lowers
// to SIL, where the enclosing effects(Never) context's NoLocks firewall catches the reference
// counting in the closure body, identically to the written-clause neverClosureArc. The firewall
// on a noescape closure argument is driven by the enclosing context, not the closure's own
// (inferred or written) row: a closure literal's SIL function carries no performance constraint,
// so bare, written-Never, and written-Locking closures are indistinguishable here.

class C {}

func applyC<E: Effect>(_ c: C, _ body: (C) effects(E) -> C) effects(E) -> C { body(c) }

// effects(Never) lowers to NoLocks: returning the class retains it, which locks.
func neverClosureArc(_ c: C) effects(Never) -> C {
  return applyC(c) { (x: C) effects(Never) -> C in return x }
  // expected-error@-1 {{this code performs reference counting operations which can cause locking}}
  // expected-note@-2 {{called from here}}
}

// effects(Locking) lowers to NoAllocation, which permits locking, so the same retain is clean.
func lockingClosureArc(_ c: C) effects(Locking) -> C {
  return applyC(c) { (x: C) effects(Locking) -> C in return x }
}

// Bare (clause-less) closure in an effects(Never) caller: E infers to Never, and the retain is
// caught by the enclosing NoLocks context exactly as the written-clause neverClosureArc above.
func neverInferredArc(_ c: C) effects(Never) -> C {
  return applyC(c) { (x: C) in return x }
  // expected-error@-1 {{this code performs reference counting operations which can cause locking}}
  // expected-note@-2 {{called from here}}
}

// Bare closure in a caller with no effects clause of its own: E still infers to Never, and the
// retain is caught by applyC's archetype-derived NoLocks constraint recursing into the noescape
// closure body. The rejection here is driven by the wrapper's row, not the caller's, isolating
// the inferred row's effect on lowering.
func plainCallerBareArc(_ c: C) -> C {
  return applyC(c) { (x: C) in return x }
  // expected-error@-1 {{this code performs reference counting operations which can cause locking}}
  // expected-note@-2 {{called from here}}
}

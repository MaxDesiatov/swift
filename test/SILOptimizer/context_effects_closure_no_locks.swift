// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s -o /dev/null -verify
// REQUIRES: optimized_stdlib
// REQUIRES: swift_feature_ContextEffects

// End-to-end: a closure literal's written effects(E) row parses, binds E, and drives the SIL
// NoLocks firewall on the closure's own body. The row on the LITERAL is load-bearing here: with no
// clause, E fails to infer (see effect_generics_infer_closure.swift), so these diagnostics prove
// the written row reached SIL, not that E was recovered from context.

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

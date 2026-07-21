// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s -o /dev/null -verify
// REQUIRES: swift_feature_ContextEffects

// An Allocation-refined variable effect row maps to the None tier, which permits
// the metadata a nested effect-generic call (e.g. withExtendedLifetime)
// instantiates, so such a wrapper may forward its closure through that callee.
// Constrained tiers (Locking, unconstrained Effect) and non-effect-generic
// forwarders stay rejected.

@_spi(ExperimentalContextEffects) import Swift

class C {}

func withExtendedLifetime<T: ~Copyable & ~Escapable, Eff: Effect, F: Error, R: ~Copyable>(
  _ x: borrowing T, _ body: () effects(Eff) throws(F) -> R
) effects(Eff) throws(F) -> R { defer { extendLifetime(x) }; return try body() }

// POSITIVE: Eff: Allocation, forwarding the closure parameter.
func allocForward<Eff: Allocation>(_ c: C, _ body: () effects(Eff) -> C) effects(Eff) -> C {
  return withExtendedLifetime(c, body)
}
// POSITIVE: Eff: Allocation, materializing a forwarding closure.
func allocMaterialize<Eff: Allocation>(_ c: C, _ body: () effects(Eff) -> C) effects(Eff) -> C {
  return withExtendedLifetime(c) { () effects(Eff) in return body() }
}
// POSITIVE: Eff: Allocation through a protocol witness.
protocol AllocWrapper {
  func wrap<Eff: Allocation>(_ c: C, _ body: () effects(Eff) -> C) effects(Eff) -> C
}
struct S: AllocWrapper {
  func wrap<Eff: Allocation>(_ c: C, _ body: () effects(Eff) -> C) effects(Eff) -> C {
    return withExtendedLifetime(c, body)
  }
}
// POSITIVE: a user protocol transitively refining Allocation.
protocol MyAlloc: Allocation {}
func userProtoForward<Eff: MyAlloc>(_ c: C, _ body: () effects(Eff) -> C) effects(Eff) -> C {
  return withExtendedLifetime(c, body)
}
// POSITIVE: an associated-type Allocation effect row.
protocol HasEff { associatedtype E: Allocation }
func assocForward<W: HasEff>(_ w: W, _ c: C, _ body: () effects(W.E) -> C) effects(W.E) -> C {
  return withExtendedLifetime(c, body)
}
// POSITIVE: a concrete effects(Allocation) row is not a type parameter, so the
// forwarding trust does not apply; it passes via per-instantiation specialization.
func concreteAllocForward(_ c: C, _ body: () effects(Allocation) -> C) effects(Allocation) -> C {
  return withExtendedLifetime(c, body)
}
// POSITIVE: forwarding into a NoAllocation-tier callee (not only NoLocks
// withExtendedLifetime); a concrete allocating instantiation specializes the
// callee to the None tier.
func lockingCallee<L: Locking>(_ body: () effects(L) -> C) effects(L) -> C { return body() }
func allocForwardIntoLocking<Eff: Allocation>(_ body: () effects(Eff) -> C) effects(Eff) -> C {
  return lockingCallee(body)
}

// NEGATIVE: Eff: Locking rejected; the NoAllocation tier hits the metadata wall.
func lockForward<Eff: Locking>(_ c: C, _ body: () effects(Eff) -> C) effects(Eff) -> C {
  return withExtendedLifetime(c, body) // expected-error {{generic closures or local functions can cause metadata allocation or locks}}
}
// NEGATIVE: unconstrained Eff: Effect rejected (NoLocks tier).
func effForward<Eff: Effect>(_ c: C, _ body: () effects(Eff) -> C) effects(Eff) -> C {
  return withExtendedLifetime(c, body) // expected-error {{generic closures or local functions can cause metadata allocation or locks}}
}
// NEGATIVE: a user protocol refining Locking is not Allocation-refined; it stays at
// the constrained NoAllocation tier and is rejected.
protocol MyLock: Locking {}
func userLockForward<Eff: MyLock>(_ c: C, _ body: () effects(Eff) -> C) effects(Eff) -> C {
  return withExtendedLifetime(c, body) // expected-error {{generic closures or local functions can cause metadata allocation or locks}}
}

// SOUNDNESS GUARD: the forwarding trust is scoped to Allocation-refined variable
// rows, so a non-effect-generic None-tier forwarder must still be rejected.
@_noLocks func noLocksCallee(_ body: () -> Int) -> Int { return body() }
func unannotatedForward(_ body: () -> Int) -> Int {
  return noLocksCallee(body) // expected-error {{called function is not known at compile time and can have unpredictable performance}}
}

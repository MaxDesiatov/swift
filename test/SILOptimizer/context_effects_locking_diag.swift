// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s -o /dev/null -verify
// REQUIRES: optimized_stdlib
// REQUIRES: swift_feature_ContextEffects

class C {}

// effects(Never) lowers to NoLocks: ARC on a class value is RefCounting, which locks.
func neverArc(_ c: C) effects(Never) -> C {
  return c // expected-error {{this code performs reference counting operations which can cause locking}}
}

// effects(Locking) lowers to NoAllocation, which permits locking, so ARC is allowed.
func lockingArc(_ c: C) effects(Locking) -> C {
  return c
}

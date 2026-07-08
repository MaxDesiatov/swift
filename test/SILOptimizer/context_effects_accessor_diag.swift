// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s -o /dev/null -verify
// REQUIRES: optimized_stdlib
// REQUIRES: swift_feature_ContextEffects

// A property getter carrying effects(Never) lowers to NoLocks, so ARC in its
// body is diagnosed -- the same teeth as the free-function case, proving the
// accessor's declared-effects row reaches SILFunctionBuilder.

class C {}

struct S {
  var c: C
  var g: C {
    get effects(Never) {
      return c // expected-error {{this code performs reference counting operations which can cause locking}}
    }
  }
}

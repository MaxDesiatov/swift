// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s -o /dev/null -verify
// REQUIRES: optimized_stdlib
// REQUIRES: swift_feature_ContextEffects

// effects(Allocation) maps to the None performance tier, which permits
// retain/release of a class value.

@_spi(ExperimentalContextEffects) import Swift

class C {}

func f(_ c: C) effects(Allocation) -> C {
  return c
}

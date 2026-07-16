// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s -o /dev/null -verify
// REQUIRES: swift_feature_ContextEffects

// A closure literal typed `() effects(Allocation) -> ...` is handler-less
// (Allocation refines Locking), so it must not synthesize a handler generic
// param; that synthesis aborted in SILGen.

@_spi(ExperimentalContextEffects) import Swift

func takesClosure(_ body: () effects(Allocation) -> Void) effects(Allocation) {
  body()
}

func caller() effects(Allocation) {
  takesClosure { }
}

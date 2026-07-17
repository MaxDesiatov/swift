// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s | %FileCheck %s
// REQUIRES: swift_feature_ContextEffects

@_spi(ExperimentalContextEffects) import Swift

// Eff: Allocation -> None tier (no perf attribute between `hidden` and `@`).
// CHECK: sil hidden @{{.*}}14allocationTier{{.*}} : $@convention(thin) <Eff where Eff : Allocation>
func allocationTier<Eff: Allocation>(_ b: () effects(Eff) -> Void) effects(Eff) { b() }

// Eff: Allocation & Locking canonicalizes to Allocation; Allocation-first must still yield None.
// CHECK: sil hidden @{{.*}}8bothTier{{.*}} : $@convention(thin) <Eff where Eff : Allocation>
func bothTier<Eff: Allocation & Locking>(_ b: () effects(Eff) -> Void) effects(Eff) { b() }

// Eff: Locking -> NoAllocation.
// CHECK: sil hidden [no_allocation] [perf_constraint] @{{.*}}11lockingTier
func lockingTier<Eff: Locking>(_ b: () effects(Eff) -> Void) effects(Eff) { b() }

// Eff: Effect (unconstrained) -> NoLocks.
// CHECK: sil hidden [no_locks] [perf_constraint] @{{.*}}10effectTier
func effectTier<Eff: Effect>(_ b: () effects(Eff) -> Void) effects(Eff) { b() }

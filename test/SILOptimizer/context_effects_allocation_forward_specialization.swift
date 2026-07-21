// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s | %FileCheck %s
// REQUIRES: swift_feature_ContextEffects

// At a concrete allocating instantiation the mandatory effect specializer emits
// a None-tier clone of the callee, so its [no_allocation] generic template never
// runs the allocating closure.

@_spi(ExperimentalContextEffects) import Swift

class C {}

func deallocsAlloc(_ c: consuming C) effects(Allocation) {}

func lockOnlySink<L: Locking>(_ body: () effects(L) -> Void) effects(L) -> Void { body() }

func fwd<Eff: Allocation>(_ body: () effects(Eff) -> Void) effects(Eff) -> Void { lockOnlySink(body) }

func caller(_ x: C) { fwd { () effects(Allocation) in deallocsAlloc(x) } }

// CHECK-DAG: sil shared @{{.*}}lockOnlySink{{.*}}Allocation{{.*}}Tg5 : {{.*}}for <Allocation>) -> () {
// CHECK-DAG: sil hidden [no_allocation] [perf_constraint] @{{.*}}lockOnlySink{{.*}}LockingRzlF :

// CHECK-LABEL: sil shared @{{.*}}fwd{{.*}}Allocation{{.*}}Tg5
// CHECK: function_ref @{{.*}}lockOnlySink{{.*}}Allocation{{.*}}Tg5

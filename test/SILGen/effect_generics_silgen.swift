// RUN: %target-swift-emit-silgen -enable-experimental-feature ContextEffects %s | %FileCheck %s
// REQUIRES: swift_feature_ContextEffects

// A variable effect row (effect generic) must lower through SIL abstraction
// patterns without leaking its type parameter into a signature-less type.

struct Box<E: Effect> { var f: () effects(E) -> Void }

// Substituting E := Never lowers to a concrete pure closure.
// CHECK-LABEL: sil hidden {{.*}} @$s{{.*}}3use{{.*}} : $@convention(thin) (@guaranteed Box<Never>) -> @owned @callee_guaranteed () -> ()
func use(_ b: Box<Never>) -> (() effects(Never) -> Void) { b.f }

// The variable row lowers into the substitution as a fresh generic parameter. The variable row
// also constrains the wrapper's own body: it maps to [no_locks] (E can bind Never).
// CHECK-LABEL: sil hidden [no_locks] [ossa] @$s{{.*}}7forward{{.*}} : $@convention(thin) <E where E : Effect> (@guaranteed @noescape @callee_guaranteed @substituted <τ_0_0> () -> () for <E>) -> ()
func forward<E: Effect>(_ body: () effects(E) -> Void) effects(E) { body() }

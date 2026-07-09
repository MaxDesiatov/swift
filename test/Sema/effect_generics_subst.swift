// RUN: %target-swift-frontend -enable-experimental-feature ContextEffects -dump-ast %s | %FileCheck %s
// REQUIRES: swift_feature_ContextEffects
struct Box<E: Effect> { var f: () effects(E) -> Void }
func use(_ b: Box<Never>) { _ = b.f }
// After subst E := Never, b.f carries the row.
// CHECK: member_ref_expr type="() effects(Never) -> Void"{{.*}}E -> Never

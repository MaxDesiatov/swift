// RUN: %target-swift-frontend -dump-parse %s -enable-experimental-feature ContextEffects 2>&1 | %FileCheck %s
// REQUIRES: swift_feature_ContextEffects

protocol FileSystem: Effect {}

func noParams() {
  // CHECK: closure_expr
  // CHECK: declared_effects
  // CHECK-NOT: error:
  let _ = { () effects(Never) in () }
}

func withParamsAndResult() {
  // CHECK: closure_expr
  // CHECK: declared_effects
  let _ = { (x: Int) effects(FileSystem) -> Int in x }
}

// Capture list co-occurring with an effects clause: the signature lookahead skips the [..] capture
// list before reaching the specifiers, so both must parse together.
func withCaptureList() {
  let obj = FileSystem.self
  // CHECK: closure_expr
  // CHECK: declared_effects
  let _ = { [obj] () effects(Never) in _ = obj }
}

// Positive co-occurrence with async/throws in the canonical order (effects before async/throws).
func withAsyncThrows() {
  // CHECK: closure_expr
  // CHECK: declared_effects
  let _ = { () effects(Never) async throws in () }
}

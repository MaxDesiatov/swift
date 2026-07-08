// RUN: %empty-directory(%t)
// RUN: %target-swift-frontend -emit-module -module-name def_context_effects -o %t \
// RUN:   -enable-experimental-feature ContextEffects %S/Inputs/def_context_effects.swift
// RUN: %llvm-bcanalyzer %t/def_context_effects.swiftmodule | %FileCheck %s
// RUN: %target-swift-ide-test -print-module -module-to-print def_context_effects \
// RUN:   -source-filename x -I %t -enable-experimental-feature ContextEffects \
// RUN:   | %FileCheck %s -check-prefix=CHECK-PRINT
// RUN: %target-swift-frontend -typecheck -verify -I %t \
// RUN:   -enable-experimental-feature ContextEffects %s
// RUN: %target-swift-frontend -emit-sil -verify -I %t -o /dev/null \
// RUN:   -enable-experimental-feature ContextEffects %s

// REQUIRES: swift_feature_ContextEffects

// CHECK-NOT: UnknownCode

// The deserialized rows are rebuilt onto each decl's interface type and print
// back, proving the row survived (not just that -verify saw no diagnostics).
// CHECK-PRINT-DAG: func neverCallee() effects(Never)
// CHECK-PRINT-DAG: func lockingCallee() effects(Locking)
// CHECK-PRINT-DAG: func e1Callee() effects(E1)
// CHECK-PRINT-DAG: func compositionCallee() effects(E1 & E2)
// CHECK-PRINT-DAG: func m() effects(Never)

@_spi(ExperimentalContextEffects) import def_context_effects

// A deserialized restrictive callee must be seen as carrying its effects row,
// so calling it from a matching restricted context is allowed. Before the row
// is serialized, the importer sees no clause and rejects each call.
func useNever() effects(Never) {
  neverCallee()
}

func useLocking() effects(Locking) {
  lockingCallee()
}

func useE1() effects(E1) {
  e1Callee()
}

func useComposition() effects(E1 & E2) {
  compositionCallee()
}

// Cross-module witness matching: a source protocol requires effects(Never) and a
// deserialized method (S.m, which carries effects(Never)) is matched against it
// under retroactive conformance. Without the serialized row the witness is seen
// as having no clause and conformance is spuriously rejected.
protocol P {
  func m() effects(Never)
}
extension S: P {}


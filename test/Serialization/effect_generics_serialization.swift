// RUN: %empty-directory(%t)
// RUN: %target-swift-frontend -emit-module -module-name effect_generics_lib -o %t \
// RUN:   -enable-experimental-feature ContextEffects %S/Inputs/effect_generics_lib.swift
// RUN: %llvm-bcanalyzer %t/effect_generics_lib.swiftmodule | %FileCheck %s
// RUN: %target-swift-ide-test -print-module -module-to-print effect_generics_lib \
// RUN:   -source-filename x -I %t -enable-experimental-feature ContextEffects \
// RUN:   | %FileCheck %s -check-prefix=CHECK-PRINT
// RUN: %target-swift-frontend -typecheck -verify -I %t \
// RUN:   -enable-experimental-feature ContextEffects %s

// REQUIRES: swift_feature_ContextEffects

// CHECK-NOT: UnknownCode

// The deserialized variable row is rebuilt onto the interface type and prints
// back in both positions, proving round-trip (not just that -verify was silent).
// CHECK-PRINT: func forward<Result, E>(_ body: () effects(E) -> Result) effects(E) -> Result where E : {{(Swift::)?}}Effect

@_spi(ExperimentalContextEffects) import Swift
@_spi(ExperimentalContextEffects) import effect_generics_lib

protocol FileSystem: Effect {}
func fsUse() effects(FileSystem) {}

// A clause-less closure binds E := Never (the strictest ceiling), so the
// deserialized forward is clean in a Never context.
func pure() effects(Never) { forward { } }

// A written effects(FileSystem) row binds E := FileSystem, so the deserialized
// forward carries effects(FileSystem) and is rejected from a Never context.
func bad() effects(Never) {
  forward { () effects(FileSystem) in fsUse() }
  // expected-error@-1 {{call to function that has effects is not allowed in a 'effects(Never)' context}}
}

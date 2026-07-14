// RUN: %empty-directory(%t)
// RUN: %target-swift-frontend -emit-module -module-name ResilientLib -o %t/ResilientLib.swiftmodule \
// RUN:   -enable-library-evolution -enable-experimental-feature ContextEffects -swift-version 5 %S/Inputs/context_effects_resilient_lib.swift
// RUN: %target-swift-frontend -parse-as-library -emit-sil -verify -I %t \
// RUN:   -enable-experimental-feature ContextEffects -swift-version 5 %s -o /dev/null
// REQUIRES: optimized_stdlib
// REQUIRES: swift_feature_ContextEffects

@_spi(ExperimentalContextEffects) import ResilientLib

class C {}

// An effects(Never) client forwarding through the opaque effects(E) generic still diagnoses: the
// resilience boundary blocks specialization, so runtime metadata is passed. Holds for BOTH a concrete
// type argument and a forwarded generic one -- the trigger is the opaque boundary, not leaf genericity.
func concreteThroughOpaque(_ c: C) effects(Never) {
  resilientForward(c) { } // expected-error {{generic function calls can cause metadata allocation or locks}}
}
func genericThroughOpaque<T>(_ x: borrowing T) effects(Never) {
  resilientForward(x) { } // expected-error {{generic function calls can cause metadata allocation or locks}}
}

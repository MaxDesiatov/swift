// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s -o /dev/null -verify
// REQUIRES: swift_feature_ContextEffects

// A Locking member forces a composition's body to NoAllocation even alongside a
// handler effect; an Allocation member leaves it unconstrained.

@_spi(ExperimentalContextEffects) import Swift

class C {}
protocol FileSystem: Effect {}

// Locking member: deallocating the owned value is forbidden.
func lockingComposed(_ c: consuming C) effects(Locking & FileSystem) {} // expected-error {{ending the lifetime of a value of type 'C' can cause a deallocation}}

// Order-independent.
func lockingComposedSwapped(_ c: consuming C) effects(FileSystem & Locking) {} // expected-error {{ending the lifetime of a value of type 'C' can cause a deallocation}}

// Allocation member: unconstrained.
func allocationComposed(_ c: consuming C) effects(Allocation & FileSystem) {}

// Sugar keeps both members (get skips minimization), so this exercises the
// Allocation-first check; Allocation permits deallocation.
typealias Alloc = Allocation
func allocationLockingSugared(_ c: consuming C) effects(Alloc & Locking) {}

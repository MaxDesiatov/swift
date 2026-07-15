// RUN: %empty-directory(%t)
// RUN: split-file %s %t
// RUN: %target-swift-frontend -emit-module -enable-experimental-feature ContextEffects -module-name EffectLib -o %t/EffectLib.swiftmodule %t/EffectLib.swift
// RUN: %target-swift-frontend -typecheck -verify -enable-experimental-feature ContextEffects -I %t %t/Main.swift
// RUN: not %target-swift-frontend -typecheck -enable-experimental-feature ContextEffects -I %t %t/Disjoint.swift 2>&1 | %FileCheck %s

// REQUIRES: swift_feature_ContextEffects

// Overloads that differ only by declared-effects row are ranked by the row: the
// tighter (subtype) ceiling is more specialized, so a downstream same-signature
// declaration shadowing a library one (the swift-atomics shape) stays resolvable.
// Each call is placed in a caller whose ceiling accepts only the tighter overload,
// so a clean typecheck proves the tighter one was selected (the looser overload
// would be rejected in that restricted context). Disjoint rows have no subtype
// relation, so that call stays ambiguous.

//--- EffectLib.swift
@_spi(ExperimentalContextEffects) import Swift
@_spi(ExperimentalContextEffects) public protocol A: Effect {}
@_spi(ExperimentalContextEffects) public protocol B: Effect {}
@_spi(ExperimentalContextEffects) public protocol Base2: Effect {}
@_spi(ExperimentalContextEffects) public protocol Refined2: Base2 {}

public func bottom(_ x: Int) effects(Never) -> Int { x }
public func mid(_ x: Int) effects(Locking) -> Int { x }
@_spi(ExperimentalContextEffects) public func comp(_ x: Int) effects(A & B) -> Int { x }
@_spi(ExperimentalContextEffects) public func disjoint(_ x: Int) effects(A) -> Int { x }
@_spi(ExperimentalContextEffects) public func ref(_ x: Int) effects(Refined2) -> Int { x }

//--- Main.swift
@_spi(ExperimentalContextEffects) import EffectLib

// present(Never) library overload vs an absent-row (top) shim: the present row is
// tighter, so it wins; legal in an effects(Never) caller.
func bottom(_ x: Int) -> Int { x }
func usesBottom() effects(Never) -> Int { bottom(0) }

// concrete effects(Never) shim vs effects(Locking) library: Never's empty set is a
// subset of {Locking}, so the shim wins; legal in an effects(Never) caller.
func mid(_ x: Int) effects(Never) -> Int { x }
func usesMid() effects(Never) -> Int { mid(0) }

// effects(A) shim vs effects(A & B) library: {A} is a subset of {A, B}, so the shim
// wins; legal in an effects(A) caller.
func comp(_ x: Int) effects(A) -> Int { x }
func usesComp() effects(A) -> Int { comp(0) }

// effects(Base2) shim vs effects(Refined2) library (Refined2: Base2): the
// less-refined effects(Base2) row is the tighter subtype, so the shim wins;
// legal in an effects(Refined2) caller.
func ref(_ x: Int) effects(Base2) -> Int { x }
func usesRef() effects(Refined2) -> Int { ref(0) }

//--- Disjoint.swift
@_spi(ExperimentalContextEffects) import EffectLib

// disjoint effects(A) library vs effects(B) shim: neither row is a subtype of the
// other, so there is no more-specialized candidate and the call stays ambiguous.
func disjoint(_ x: Int) effects(B) -> Int { x }
func usesDisjoint() -> Int {
  // CHECK: ambiguous use of 'disjoint'
  disjoint(0)
}

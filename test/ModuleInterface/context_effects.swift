// RUN: %empty-directory(%t)
// RUN: %target-swift-emit-module-interface(%t/context_effects.swiftinterface) %s \
// RUN:   -enable-experimental-feature ContextEffects
// RUN: %target-swift-typecheck-module-from-interface(%t/context_effects.swiftinterface) \
// RUN:   -enable-experimental-feature ContextEffects
// RUN: %FileCheck %s < %t/context_effects.swiftinterface

// REQUIRES: swift_feature_ContextEffects

// .swiftinterface prints module-qualified names with the `::` module selector,
// so the effect protocol prints as `Swift::Never` / `Swift::Locking`.

// CHECK: public func f() effects(Swift::Never)
public func f() effects(Never) {}

// CHECK: public func g() effects(Swift::Locking)
public func g() effects(Locking) {}

// An accessor's effects(...) clause must round-trip through the interface too,
// not just free functions.
public struct S {
  // CHECK: public var v: Swift::Int {
  // CHECK: get effects(Swift::Never)
  public var v: Int { get effects(Never) { 0 } }
}

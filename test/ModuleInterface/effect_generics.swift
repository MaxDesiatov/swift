// RUN: %empty-directory(%t)
// RUN: %target-swift-emit-module-interfaces(%t/Lib.swiftinterface, %t/Lib.private.swiftinterface) \
// RUN:   -module-name Lib -enable-experimental-feature ContextEffects %s
// RUN: %target-swift-typecheck-module-from-interface(%t/Lib.private.swiftinterface) \
// RUN:   -module-name Lib -enable-experimental-feature ContextEffects
// RUN: %FileCheck %s < %t/Lib.private.swiftinterface

// REQUIRES: swift_feature_ContextEffects

// CHECK: public func forward<Result, E>(_ body: () effects(E) -> Result) effects(E) -> Result where E : Swift::Effect

@_spi(ExperimentalContextEffects) import Swift
@_spi(ExperimentalContextEffects)
public func forward<Result, E: Effect>(_ body: () effects(E) -> Result) effects(E) -> Result { body() }

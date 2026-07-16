// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s -o /dev/null -verify
// REQUIRES: swift_feature_ContextEffects

// Per-instantiation effect specialization seeds only on direct applies
// (getReferencedFunctionOrNull), so an effect-generic requirement reached
// through witness dispatch is never specialized and stays rejected.

@_spi(ExperimentalContextEffects) import Swift

class C {}

protocol P {
  func wrap<Eff: Effect>(_ c: C, _ body: () effects(Eff) -> C) effects(Eff) -> C
}

struct S: P {
  func wrap<Eff: Effect>(_ c: C, _ body: () effects(Eff) -> C) effects(Eff) -> C { // expected-error {{called function is not known at compile time and can have unpredictable performance}}
    return body()
  }
}

func viaWitness(_ p: any P, _ c: C) effects(Allocation) -> C {
  return p.wrap(c) { () effects(Allocation) in return c }
}

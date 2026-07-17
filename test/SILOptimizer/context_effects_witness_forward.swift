// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s -o /dev/null -verify
// REQUIRES: swift_feature_ContextEffects

// A protocol requirement that forwards an effect through a closure parameter.
// The witness body only forwards, so it performs no effect of its own; the
// witness thunk must not reject the forwarded closure.

@_spi(ExperimentalContextEffects) import Swift

class C {}

protocol Forwarder {
  func run<Eff: Effect>(_ c: C, _ body: () effects(Eff) -> C) effects(Eff) -> C
}

struct S: Forwarder {
  func run<Eff: Effect>(_ c: C, _ body: () effects(Eff) -> C) effects(Eff) -> C {
    return body()
  }
}

func viaConcrete(_ s: S, _ c: C) effects(Allocation) -> C {
  return s.run(c) { () effects(Allocation) in return c }
}

func viaGeneric<F: Forwarder>(_ f: F, _ c: C) effects(Allocation) -> C {
  return f.run(c) { () effects(Allocation) in return c }
}

func viaExistential(_ f: any Forwarder, _ c: C) effects(Allocation) -> C {
  return f.run(c) { () effects(Allocation) in return c }
}

// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s -o /dev/null -verify
// REQUIRES: swift_feature_ContextEffects

// A witness that forwards its effect by MATERIALIZING a generic closure (rather
// than forwarding its own closure parameter) is still rejected: the closure
// literal needs type metadata under the abstract-row tier. This is a separate
// limitation from the pure-forwarding case, which is accepted.

@_spi(ExperimentalContextEffects) import Swift

class C {}

func withExtendedLifetime<T: ~Copyable & ~Escapable, Eff: Effect, F: Error, R: ~Copyable>(
  _ x: borrowing T, _ body: () effects(Eff) throws(F) -> R
) effects(Eff) throws(F) -> R { defer { extendLifetime(x) }; return try body() }

protocol Wrapper {
  func wrap<Eff: Effect>(_ c: C, _ body: () effects(Eff) -> C) effects(Eff) -> C
}
struct S: Wrapper {
  func wrap<Eff: Effect>(_ c: C, _ body: () effects(Eff) -> C) effects(Eff) -> C {
    return withExtendedLifetime(c) { () effects(Eff) in return body() } // expected-error {{generic closures or local functions can cause metadata allocation or locks}}
  }
}

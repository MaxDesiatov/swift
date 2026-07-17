// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s -o /dev/null -verify
// REQUIRES: swift_feature_ContextEffects

// A constrained variable row is classified by its bound: Eff: Allocation is the
// unconstrained tier (deallocation allowed); Eff: Locking forbids deallocation;
// an unconstrained Eff: Effect stays NoLocks.

@_spi(ExperimentalContextEffects) import Swift

class C {}

// Eff: Allocation, free: deallocating the owned `c` is permitted.
func freeRelease<Eff: Allocation>(_ c: consuming C, _ body: () effects(Eff) -> Void) effects(Eff) {
  body()
}

// Eff: Allocation, witness: same body, through the witness thunk.
protocol Releaser {
  func release<Eff: Allocation>(_ c: consuming C, _ body: () effects(Eff) -> Void) effects(Eff)
}
struct S: Releaser {
  func release<Eff: Allocation>(_ c: consuming C, _ body: () effects(Eff) -> Void) effects(Eff) {
    body()
  }
}

// (iii) Unconstrained Eff: Effect deallocating -> a Never binding forbids it.
// The diagnostic anchors to the consuming parameter, whose value is destroyed
// in the body.
func effUnconstrained<Eff: Effect>(_ c: consuming C, _ body: () effects(Eff) -> Void) effects(Eff) { // expected-error {{ending the lifetime of a value of type 'C' can cause a deallocation}}
  body()
}

// Eff: Locking deallocating -> NoAllocation forbids deallocation.
func lockingDealloc<Eff: Locking>(_ c: consuming C, _ body: () effects(Eff) -> Void) effects(Eff) { // expected-error {{ending the lifetime of a value of type 'C' can cause a deallocation}}
  body()
}

// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s -o /dev/null -verify
// REQUIRES: optimized_stdlib
// REQUIRES: swift_feature_ContextEffects

// Locks the effect->PerformanceConstraints mapping against the attribute it replaces:
// effects(Never) == @_noLocks (NoLocks), effects(Locking) == @_noAllocation (NoAllocation).
// Invariant: every construct is a SILGen-inserted implicit runtime effect, never an explicit
// call to an unannotated function -- such a call is intercepted by the Sema effect-subset
// check on the effect spelling only, breaking parity. ARC is the sole discriminator a normal
// annotated function can express (the pure Locking bit comes only from global-init machinery,
// which takes no effects clause).

class Cl {}

// Reference counting -- diagnosed under NoLocks, permitted under NoAllocation (discriminator).
@_noLocks
func arc_attr_never(_ x: Cl) -> Cl {
  return x // expected-error {{this code performs reference counting operations which can cause locking}}
}
func arc_eff_never(_ x: Cl) effects(Never) -> Cl {
  return x // expected-error {{this code performs reference counting operations which can cause locking}}
}
@_noAllocation
func arc_attr_locking(_ x: Cl) -> Cl { return x }
func arc_eff_locking(_ x: Cl) effects(Locking) -> Cl { return x }

// Metadata (generic value copy) -- diagnosed under both constraints.
@_noLocks
func meta_attr_never<T>(_ x: T) { let y = x; _ = y } // expected-error {{Using type 'T' can cause metadata allocation or locks}}
func meta_eff_never<T>(_ x: T) effects(Never) { let y = x; _ = y } // expected-error {{Using type 'T' can cause metadata allocation or locks}}
@_noAllocation
func meta_attr_locking<T>(_ x: T) { let y = x; _ = y } // expected-error {{Using type 'T' can cause metadata allocation or locks}}
func meta_eff_locking<T>(_ x: T) effects(Locking) { let y = x; _ = y } // expected-error {{Using type 'T' can cause metadata allocation or locks}}

// Deallocation (owned class release) -- diagnosed under both constraints.
@_noLocks
func dealloc_attr_never(_ c: __owned Cl) {} // expected-error {{ending the lifetime of a value of type 'Cl' can cause a deallocation}}
func dealloc_eff_never(_ c: __owned Cl) effects(Never) {} // expected-error {{ending the lifetime of a value of type 'Cl' can cause a deallocation}}
@_noAllocation
func dealloc_attr_locking(_ c: __owned Cl) {} // expected-error {{ending the lifetime of a value of type 'Cl' can cause a deallocation}}
func dealloc_eff_locking(_ c: __owned Cl) effects(Locking) {} // expected-error {{ending the lifetime of a value of type 'Cl' can cause a deallocation}}

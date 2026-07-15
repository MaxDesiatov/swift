// RUN: %target-swift-frontend -parse-as-library -enable-experimental-feature ContextEffects -emit-sil %s -o /dev/null -verify
// REQUIRES: optimized_stdlib
// REQUIRES: swift_feature_ContextEffects

class C {}

// A polymorphic effects(E) wrapper's own body is checked under NoLocks: E can bind Never, so
// retaining a class in the wrapper body is rejected. `return keep` is a live retain (survives
// -Onone copy-propagation, unlike a discarded copy). E is referenced in `body`'s type, so the
// decl is well-formed; `body` is uncalled here to isolate the teeth on the wrapper's own body.
func wrapperOwnArc<E: Effect>(_ keep: C, _ body: () effects(E) -> Void) effects(E) -> C {
  return keep // expected-error {{this code performs reference counting operations which can cause locking}}
}

// The branch fires for a combined effects(E) throws row too (the with- family's real shape).
func wrapperOwnArcThrows<E: Effect>(_ keep: C, _ body: () effects(E) -> Void) effects(E) throws -> C {
  return keep // expected-error {{this code performs reference counting operations which can cause locking}}
}

// A pure forwarder with a concrete loadable result stays clean: the forwarded body() call is
// trusted as a closure argument already checked at the call site.
func cleanForwardInt<E: Effect>(_ body: () effects(E) -> Int) effects(E) -> Int {
  return body()
}

// The with- family's real shape: a generic-Result forwarder stays clean under NoLocks. `return
// body()` initializes the @out result directly (no intermediate copy_addr, so no metadata op),
// and the noescape closure value is trivial for ARC, so neither firewall fires.
func cleanForwardResult<Result, E: Effect>(_ body: () effects(E) -> Result) effects(E) -> Result {
  return body()
}

// A stored effects(E) closure property: its getter returns a value whose type carries E, but the
// getter itself performs no effects, so it is unconstrained and its escaping-closure return is
// clean. Guards getResolvedDeclaredEffectsType against attributing a result-type row to the decl.
struct Box<E: Effect> { var f: () effects(E) -> Void }
func readBox(_ b: Box<Never>) -> (() effects(Never) -> Void) { return b.f }

// A plain function that only returns an effects(Never) closure is likewise unconstrained: the row
// is part of the returned value's type, not this function's context.
func makeNeverClosure(_ keep: C) -> (() effects(Never) -> Void) { return { _ = keep } }

// Forwarding the caller's own archetype T to a named generic function is clean: T's
// metadata is a passed-in ABI argument in this frame, so the call reads it rather than
// instantiating it.
func genericSink<T>(_ x: T) effects(Never) {}
func forwardThroughNamed<T, E: Effect>(_ x: T, _ body: () effects(E) -> Void) effects(E) {
  genericSink(x)
}

// Forwarding a bound generic (not a bare archetype) still diagnoses, because
// Wrapper<T>'s metadata may be instantiated (swift_getGenericMetadata) rather
// than passed in. Fails if the apply relaxation is ever broadened from
// PrimaryArchetypeType to hasArchetype().
struct Wrapper<T> {}
func boundGenericCallStillDiagnosed<T>(_ x: Wrapper<T>) effects(Never) {
  genericSink(x) // expected-error {{generic function calls can cause metadata allocation or locks}}
}

// The with- family's real (throwing) shape. `try body()` needs a local error slot, lowering to
// `alloc_stack $E` + `copy_addr [take] $*E`, both reading E's passed-in metadata. Those bare-archetype
// reads are non-hazardous, so the forwarder is clean under NoLocks, matching cleanForwardResult
// (which returns to @out and needs no error slot).
func cleanForwardEffectThrows<Eff: Effect, E: Error, Result>(
  _ body: () effects(Eff) throws(E) -> Result
) effects(Eff) throws(E) -> Result {
  return try body()
}

// The clearing holds under NoAllocation too, not only NoLocks (the metadata branch fires under both):
// a @_noAllocation typed-throws forwarder's error-slot metadata reads are likewise non-hazardous.
@_noAllocation
func cleanForwardNoAllocation<E: Error>(_ body: () throws(E) -> Int) throws(E) -> Int {
  return try body()
}

// The value-witness-executing paths are not relaxed: duplicating a generic value invokes its copy
// witness, which may allocate for COW / out-of-line representations, so a @_noAllocation forwarder
// copying an archetype still diagnoses.
@_noAllocation
func archetypeCopyStillDiagnosed<T>(_ x: T) -> (T, T) {
  return (x, x) // expected-error {{Using type 'T' can cause metadata allocation or locks}}
}

// A bound-generic thrown error hits the same error-slot `alloc_stack` / `copy_addr [take][init]` as
// cleanForwardEffectThrows, but Wrap<T> is not a bare archetype: its metadata may be instantiated
// (swift_getGenericMetadata), so it stays diagnosed. Pins the relaxation's by-kind boundary.
enum Wrap<T>: Error { case a(T) }
@_noAllocation
func boundGenericThrowStillDiagnosed<T>(_ body: () throws(Wrap<T>) -> Int) throws(Wrap<T>) -> Int {
  return try body() // expected-error {{Using type 'Wrap<T>' can cause metadata allocation or locks}}
}

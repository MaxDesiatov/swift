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

// Forwarding through another named generic function (not the closure parameter) passes an archetype
// type argument, which needs runtime metadata: the pre-existing NoLocks generic-call rule fires,
// exactly as it does for a concrete effects(Never) or @_noLocks generic caller.
func genericSink<T>(_ x: T) effects(Never) {}
func forwardThroughNamed<T, E: Effect>(_ x: T, _ body: () effects(E) -> Void) effects(E) {
  genericSink(x) // expected-error {{generic function calls can cause metadata allocation or locks}}
}

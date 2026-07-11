// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects
// REQUIRES: swift_feature_ContextEffects

protocol FileSystem: Effect {}
protocol Network: Effect {}
func fsFn() effects(FileSystem) -> Void {}
func netFn() effects(Network) -> Void {}

func forward<Result, E: Effect>(_ body: () effects(E) -> Result) effects(E) -> Result { body() }
// expected-note@-1 {{where 'E' = 'String'}}

// Positive: the closure's own effects(Never) row binds E := Never; the forward is clean.
func neverCaller() effects(Never) -> Void {
  forward { () effects(Never) in () }
}

// Discriminating negative: the closure body performs nothing, so an inference-from-body E would
// be Never (clean). The 'Network' mismatch fires only if the written effects(Network) row was
// honored, binding E := Network.
func fsCaller() effects(FileSystem) -> Void {
  forward { () effects(Network) in () }
  // expected-error@-1 {{call to function that has effects 'Network' is not allowed; enclosing function only has effects 'FileSystem'}}
}

// Outer generic param: the closure names the enclosing wrapper's E; resolveTypeReferenceInExpression
// resolves it against CS.DC. E binds through to the outer E; the call is clean.
func outerGeneric<E: Effect>(_ body: () effects(E) -> Void) effects(E) {
  forward { () effects(E) in body() }
}

// No-clause regression (AD-4): a bare closure with no effects clause still inherits the contextual
// row, exactly as today.
let _: () effects(FileSystem) -> Void = { fsFn() }

// A written-but-malformed clause must NOT silently fall back to contextual inference (AD-1).
let _: () effects(FileSystem) -> Void = { () effects(NoSuchType) in fsFn() }
// expected-error@-1 {{cannot find type 'NoSuchType' in scope}}

// A non-Effect member is caught by the wrapper's `E: Effect` requirement when the row binds (AD-2);
// CSGen emits no speculative conformance diagnostic of its own.
func stringRow() {
  forward { () effects(String) in () }
  // expected-error@-1 {{global function 'forward' requires that 'String' conform to 'Effect'}}
}

// Ordering + malformed negatives (the parseEffectsSpecifiers diagnostics apply to closures too).
func badOrdering() {
  let _ = { () -> Void effects(Never) in () }
  // expected-error@-1 {{'effects' may only occur before '->'}}
  let _ = { () async throws effects(Never) in () }
  // expected-error@-1 {{'effects' must appear before 'async'}}
  let _ = { () effects(Never) effects(FileSystem) in () }
  // expected-error@-1 {{'effects' has already been specified}}
  // expected-error@-2 {{'Never' cannot be combined with other types in a 'effects' clause}}
}

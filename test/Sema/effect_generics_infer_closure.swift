// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects
// REQUIRES: swift_feature_ContextEffects

protocol FileSystem: Effect {}
protocol Network: Effect {}
func fsFn() effects(FileSystem) -> Void {} // expected-note 2 {{'fsFn()' declared here}}
func netFn() effects(Network) -> Void {} // expected-note {{'netFn()' declared here}}

func forward<Result, E: Effect>(_ body: () effects(E) -> Result) effects(E) -> Result { body() }
// expected-note@-1 {{where 'E' = 'String'}}
func forwardArg<Arg, Result, E: Effect>(_ a: Arg, _ body: (Arg) effects(E) -> Result) effects(E) -> Result { body(a) }

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

// A clause-less closure passed to a variable effects(E) row defaults E := Never (the strictest
// ceiling), so inference succeeds instead of failing. Spanning empty / typed-param+result /
// multi-statement / outer-generic shapes proves the seed fires across resolveClosure's body paths.

// Empty body.
func bareNeverCaller() effects(Never) -> Void {
  forward { () }
}

// Typed parameter + explicit result, no effects clause (the SIL-test shape at the Sema layer).
func bareTypedParam() effects(Never) -> Void {
  _ = forwardArg(0) { (x: Int) -> Int in x }
}

// Multi-statement body with a local binding (a distinct resolveClosure body path).
func bareMultiStmt() effects(Never) -> Void {
  forward {
    let y = 1
    _ = y
  }
}

// Outer generic: a bare closure in a generic wrapper still defaults to Never,
// which is a subtype of any E, so the call is clean.
func bareOuter<E: Effect>(_ body: () effects(E) -> Void) effects(E) {
  forward { () }
}

// A bare closure whose body performs an effect exceeds the inferred Never ceiling;
// the error anchors at the inner call, proving E inferred to Never (not the body's effect).
func bareBodyExceeds() effects(FileSystem) -> Void {
  forward { fsFn() }
  // expected-error@-1 {{call to function that has effects is not allowed in a 'effects(Never)' context}}
}
func bareBodyExceedsNet() effects(FileSystem) -> Void {
  forward { netFn() }
  // expected-error@-1 {{call to function that has effects is not allowed in a 'effects(Never)' context}}
}

// Leak guard: a bare closure whose expected type has no effects row (plain () -> Void)
// must not be seeded with Never, so calling an effectful function stays legal.
func plainTarget() {
  let c: () -> Void = { fsFn() }
  c()
}

func forward2<E: Effect>(_ a: () effects(E) -> Void, _ b: () effects(E) -> Void) effects(E) -> Void { a(); b() }

// A bare closure sharing E with a concrete sibling adopts the sibling's row rather than pinning
// Never: the default yields to the concretely-determined E, so E := FileSystem and the call is clean.
func bareSharesConcreteSibling() effects(FileSystem) -> Void {
  forward2({ }, fsFn)
}

// Both bare: E is otherwise unconstrained, so both default to Never; the empty bodies stay within
// the Never ceiling and the call is clean.
func bothBareShareNever() {
  forward2({ }, { })
}

// One bare, one bare-effectful: both default Never (nothing determines E), so the effectful body
// exceeds the ceiling at its inner call.
func bareSharesEffectfulBare() effects(FileSystem) -> Void {
  forward2({ }, { fsFn() })
  // expected-error@-1 {{call to function that has effects is not allowed in a 'effects(Never)' context}}
}

// A concrete expected row (not a variable) is adopted verbatim, never re-seeded with Never; the
// matching effectful body is legal within that concrete ceiling.
let _: () effects(Network) -> Void = { netFn() }

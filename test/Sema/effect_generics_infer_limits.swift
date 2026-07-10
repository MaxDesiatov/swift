// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects
// REQUIRES: swift_feature_ContextEffects

// Boundaries of concrete-row effect inference. These pin current behavior for
// arguments outside the concrete-row scope; the diagnostics are correct today
// but the cases may gain inference or better messages in a later phase.

protocol FileSystem: Effect { mutating func read() -> String }
protocol Network: Effect { mutating func fetch() -> String }

func forward<Result, E: Effect>(_ body: () effects(E) -> Result) effects(E) -> Result { body() }
// expected-note@-1 {{in call to function 'forward'}}
// expected-note@-2 {{required by global function 'forward' where 'E' = 'Any'}}
func forward2<E: Effect>(_ a: () effects(E) -> Void, _ b: () effects(E) -> Void) effects(E) -> Void { a(); b() }

func plain() -> Void {}
func anyFn() effects(Any) -> Void {}
func fsFn() effects(FileSystem) -> Void {}
func nwFn() effects(Network) -> Void {}

// An absent row is the top, not Never, so a no-effects function does not infer E := Never.
func absentRowArg() effects(Never) -> Void {
  forward(plain)
  // expected-error@-1 {{generic parameter 'E' could not be inferred}}
}

// effects(Any) resolves to the absent/top row, which is not a type conforming to Effect.
func anyRowArg() {
  forward(anyFn)
  // expected-error@-1 {{type 'Any' cannot conform to 'Effect'}}
  // expected-note@-2 {{only concrete types such as structs, enums and classes can conform to protocols}}
}

// Two argument rows with no common concrete supertype join E to the bare Effect
// protocol; the call is still correctly rejected, but the row is named 'Effect'.
func multiParamJoin() effects(FileSystem) -> Void {
  forward2(fsFn, nwFn)
  // expected-error@-1 {{call to function that effects 'Effect' is not allowed; enclosing function only effects 'FileSystem'}}
}

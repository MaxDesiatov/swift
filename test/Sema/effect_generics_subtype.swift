// RUN: %target-typecheck-verify-swift -enable-experimental-feature ContextEffects
// REQUIRES: swift_feature_ContextEffects

// The concrete effect-row subtyping order in matchFunctionTypes: a function
// performing fewer effects is a subtype of one performing more. Comparison is by
// protocol identity (matching the effects walker); refinement is not subtyping.

protocol FileSystem: Effect { mutating func read() -> String }
protocol Network: Effect { mutating func fetch() -> String }
protocol ReadWrite: FileSystem { mutating func write(_ s: String) }

// Bare closures adopt the target row, giving concrete-row function values.
let fsOnly:  () effects(FileSystem) -> Void = { }
let both:    () effects(FileSystem & Network) -> Void = { }
let rw:      () effects(ReadWrite) -> Void = { }
let never:   () effects(Never) -> Void = { }
let locking: () effects(Locking) -> Void = { }
let plain:   () -> Void = { }

// Narrowing the effect set: illegal.
let narrow: () effects(FileSystem) -> Void = both
// expected-error@-1 {{invalid conversion of effects 'FileSystem & Network' to 'FileSystem'}}

// Widening the effect set: OK.
let widen: () effects(FileSystem & Network) -> Void = fsOnly

// Refinement is not subtyping in the identity-based model; both directions fail.
let refDown: () effects(FileSystem) -> Void = rw
// expected-error@-1 {{invalid conversion of effects 'ReadWrite' to 'FileSystem'}}
let refUp: () effects(ReadWrite) -> Void = fsOnly
// expected-error@-1 {{invalid conversion of effects 'FileSystem' to 'ReadWrite'}}

// Concrete row widened to unrestricted (absent = top): OK.
let toUnrestricted: () -> Void = fsOnly

// effects(Any) is the top (it resolves to an absent row): a concrete row binds.
let toAny: () effects(Any) -> Void = locking

// Unrestricted (top) to a concrete row stays permissive: an absent row is not
// narrowed (a bare closure adopts its target's row; the walker enforces calls).
let toRestricted: () effects(FileSystem) -> Void = plain

// Never is the bottom: effects(Never) <: effects(Locking); the reverse is illegal.
let neverToLocking: () effects(Locking) -> Void = never
let lockingToNever: () effects(Never) -> Void = locking
// expected-error@-1 {{invalid conversion of effects 'Locking' to 'Never'}}

// Higher-order: a function-typed parameter carrying a row exercises the
// parameter-position match and guards against spurious exact-match rejection.
func takesFn(_ f: (() effects(FileSystem) -> Void) -> Void) {}
func giveFn(_ g: (() effects(FileSystem) -> Void) -> Void) { takesFn(g) }

// Contravariant parameter position: a function whose parameter needs a narrower
// row than required cannot be passed (the swapped-argument match narrows).
func wantsFn(_ f: (() effects(FileSystem & Network) -> Void) -> Void) {}
func giveNarrowerFn(_ g: (() effects(FileSystem) -> Void) -> Void) { wantsFn(g) }
// expected-error@-1 {{invalid conversion of effects 'FileSystem & Network' to 'FileSystem'}}

// RUN: %target-typecheck-verify-swift

// Without -enable-experimental-feature ContextEffects,
// 'effects' is just an identifier, not an effect specifier.
// This test verifies the feature gate works.
func effects(_ x: Int) -> Int { x } // OK - 'effects' is a valid identifier
let _ = effects(42)

func withEffect(_ x: Int) -> Int { x } // OK
let _ = withEffect(42)

func handle(_ x: Int) -> Int { x } // OK
let _ = handle(42)

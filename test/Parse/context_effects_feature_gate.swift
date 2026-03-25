// RUN: %target-typecheck-verify-swift

// Without -enable-experimental-feature ContextEffects,
// 'performs' is just an identifier, not an effect specifier.
// This test verifies the feature gate works.
func performs(_ x: Int) -> Int { x } // OK - 'performs' is a valid identifier
let _ = performs(42)

func perform(_ x: Int) -> Int { x } // OK
let _ = perform(42)

func handle(_ x: Int) -> Int { x } // OK
let _ = handle(42)

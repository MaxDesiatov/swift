// RUN: %target-swift-frontend -primary-file %s -emit-ir -g -O -parse-as-library -disable-availability-checking
// REQUIRES: concurrency, asserts

// rdar://174881006
// Verify that replaceSubstitutedSILFunctionTypesWithUnsubstituted preserves
// SILParameterInfo options (including ImplicitLeading) when reconstructing
// SIL function types.

func test() async -> () async -> Void {
    return await withTaskCancellationHandler {
        return {}
    } onCancel: { }
}

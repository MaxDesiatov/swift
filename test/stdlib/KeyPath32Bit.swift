// RUN: %target-run-simple-swift
// RUN: %target-run-simple-swift(-O)
// REQUIRES: executable_test
// UNSUPPORTED: use_os_stdlib
// UNSUPPORTED: back_deployment_runtime

// Regression test for a 32-bit-only mask-overlap bug in `ComputedArgumentSize`
// (`stdlib/public/core/KeyPath.swift`).
//
// On 32-bit targets the buggy `alignmentMask = 0x6000_0000` (bits 29-30) does
// not cover bit 31, which is where the `alignment = 16` setter actually
// writes (`2 &<< 30 == 0x8000_0000`). As a result, the alignment field reads
// back as 0 even though it was set to 16.
//
// The field is read during keypath append in two places:
//
//   1. `calculateAppendedKeyPathSize` — uses the source component's
//      `.alignment` to decide whether to add alignment padding to the new
//      buffer. Buggy: guard fails (reads 0), no padding reserved, buffer is
//      under-allocated for a 16-aligned argument.
//   2. `_storeInto` — writes the argument bytes into the under-allocated
//      buffer.
//
// End-user-visible symptom: constructing any appended keypath whose captured
// argument type has 16-byte alignment (e.g., `SIMD4<Int32>`) under the buggy
// mask traps inside the stdlib during projection, because the stdlib detects
// the out-of-bounds write into the undersized buffer. The fix
// (`alignmentMask = 0xC000_0000`, bits 30-31) makes alignment round-trip
// correctly; the buffer is sized correctly; projection returns the expected
// value.
//
// This test exercises both paths by constructing `\Outer.inner[arg]`, which
// forces `appending(path:)` through the buggy codepath. It asserts the
// normally-computed return value (`expectEqual(expected, observed)`). Under
// the buggy mask the process traps before `expectEqual` runs; lit records
// this as a FAIL via non-zero exit code, which is a user-observable regression
// (a normally-constructed keypath that used to work now traps).
//
// On 64-bit the masks are already disjoint; this test compiles, runs, and
// trivially passes on 64-bit targets.

import StdlibUnittest

let tests = TestSuite("KeyPath32Bit")

struct Inner {
  let base: Int
  subscript(idx: SIMD4<Int32>) -> Int {
    return base &+ Int(idx[0]) &+ Int(idx[1]) &+ Int(idx[2]) &+ Int(idx[3])
  }
}

struct Outer {
  var inner: Inner
}

tests.test("appended keypath with 16-byte-aligned subscript argument") {
  // Precondition: SIMD4<Int32> must have 16-byte alignment on this target.
  // If a future stdlib change demotes the alignment, this test would stop
  // exercising the bug's codepath — assert loudly instead of silently.
  expectEqual(16, MemoryLayout<SIMD4<Int32>>.alignment)
  expectEqual(16, MemoryLayout<SIMD4<Int32>>.size)

  let arg = SIMD4<Int32>(1, 2, 3, 4)

  // The leaf keypath captures a 16-aligned argument.
  let leaf: KeyPath<Inner, Int> = \Inner.[arg]

  // `appending(path:)` forces the buggy `calculateAppendedKeyPathSize` /
  // `_storeInto` paths that read `.alignment` back from the leaf component's
  // header. Under the buggy mask, the read returns 0; the appended buffer is
  // under-allocated; projection traps inside the stdlib.
  let composed: KeyPath<Outer, Int> = (\Outer.inner).appending(path: leaf)

  // Normal keypath projection. On a correct stdlib this returns the expected
  // value. On a buggy stdlib it traps before returning, which lit records as
  // a non-zero exit code (test FAIL).
  let observed = Outer(inner: Inner(base: 100))[keyPath: composed]

  // 100 (base) + 1 + 2 + 3 + 4 = 110.
  expectEqual(110, observed)
}

runAllTests()

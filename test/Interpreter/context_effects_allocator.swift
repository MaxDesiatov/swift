// RUN: %target-run-simple-swift(-enable-experimental-feature ContextEffects) | %FileCheck %s
// REQUIRES: executable_test
// REQUIRES: swift_feature_ContextEffects

protocol Allocation: Effect {
  mutating func allocate(byteCount: Int, alignment: Int) -> UnsafeMutableRawBufferPointer?
  mutating func deallocate(buffer: UnsafeMutableRawBufferPointer)
}

struct SystemAllocator: Allocation {
  mutating func allocate(byteCount: Int, alignment: Int) -> UnsafeMutableRawBufferPointer? {
    .allocate(byteCount: byteCount, alignment: alignment)
  }
  mutating func deallocate(buffer: UnsafeMutableRawBufferPointer) {
    buffer.deallocate()
  }
}

struct BumpAllocator: Allocation {
  let region: UnsafeMutableRawBufferPointer
  var offset: Int = 0

  init(region: UnsafeMutableRawBufferPointer) effects(Never) { self.region = region }

  mutating func allocate(byteCount: Int, alignment: Int) -> UnsafeMutableRawBufferPointer? {
    let aligned = (offset + alignment - 1) & ~(alignment - 1)
    guard aligned + byteCount <= region.count else { return nil }
    let result = UnsafeMutableRawBufferPointer(
      start: region.baseAddress! + aligned, count: byteCount
    )
    offset = aligned + byteCount
    return result
  }
  mutating func deallocate(buffer: UnsafeMutableRawBufferPointer) {
    // no-op for bump allocator
  }
}

// --- Helper: allocate, write, read back via effects(Allocation) ---

func allocateAndWrite(_ value: UInt8, byteCount: Int) effects(Allocation) -> UnsafeMutableRawBufferPointer? {
  let buf = withEffect { (a: inout some Allocation) in
    a.allocate(byteCount: byteCount, alignment: 1)
  }
  if let buf {
    buf[0] = value
  }
  return buf
}

func deallocateBuffer(_ buf: UnsafeMutableRawBufferPointer) effects(Allocation) {
  withEffect { (a: inout some Allocation) in
    a.deallocate(buffer: buf)
  }
}

// === Test 1: Basic allocation with SystemAllocator ===

// CHECK-LABEL: testSystemAllocator
func testSystemAllocator() {
  print("testSystemAllocator")
  var buf: UnsafeMutableRawBufferPointer?
  do {
    buf = allocateAndWrite(42, byteCount: 16)
  } handle SystemAllocator() as Allocation
  // CHECK: allocated 16 bytes, first byte: 42
  print("allocated \(buf!.count) bytes, first byte: \(buf![0])")
  buf!.deallocate()
}
testSystemAllocator()

// === Test 2: BumpAllocator with arena ===

// CHECK-LABEL: testBumpAllocator
func testBumpAllocator() {
  print("testBumpAllocator")
  let arena = UnsafeMutableRawBufferPointer.allocate(byteCount: 4096, alignment: 16)
  defer { arena.deallocate() }
  var buf: UnsafeMutableRawBufferPointer!
  do {
    buf = allocateAndWrite(99, byteCount: 32)!
    deallocateBuffer(buf) // no-op for bump
  } handle BumpAllocator(region: arena) as Allocation
  // Verify allocation came from the arena region
  let bufStart = buf.baseAddress!
  let arenaStart = arena.baseAddress!
  let arenaEnd = arenaStart + arena.count
  let inArena = bufStart >= arenaStart && bufStart < arenaEnd
  // CHECK: bump alloc in arena: true, size: 32, first byte: 99
  print("bump alloc in arena: \(inArena), size: \(buf.count), first byte: \(buf[0])")
}
testBumpAllocator()

// === Test 3: Inout mutation — multiple allocations see sequential offsets ===

func allocateTwo() effects(Allocation) -> (UnsafeMutableRawBufferPointer?, UnsafeMutableRawBufferPointer?) {
  let first = withEffect { (a: inout some Allocation) in
    a.allocate(byteCount: 64, alignment: 8)
  }
  let second = withEffect { (a: inout some Allocation) in
    a.allocate(byteCount: 128, alignment: 8)
  }
  return (first, second)
}

// CHECK-LABEL: testInoutMutation
func testInoutMutation() {
  print("testInoutMutation")
  let arena = UnsafeMutableRawBufferPointer.allocate(byteCount: 4096, alignment: 16)
  defer { arena.deallocate() }
  var first: UnsafeMutableRawBufferPointer?
  var second: UnsafeMutableRawBufferPointer?
  do {
    (first, second) = allocateTwo()
  } handle BumpAllocator(region: arena) as Allocation
  let firstOffset = first!.baseAddress! - arena.baseAddress!
  let secondOffset = second!.baseAddress! - arena.baseAddress!
  // First alloc at offset 0, second at offset 64 (after first's 64 bytes)
  // CHECK: first offset: 0, second offset: 64
  print("first offset: \(firstOffset), second offset: \(secondOffset)")
  // CHECK: first size: 64, second size: 128
  print("first size: \(first!.count), second size: \(second!.count)")
}
testInoutMutation()

// === Test 4: Nested handlers — inner overrides outer ===

// CHECK-LABEL: testNestedHandlers
func testNestedHandlers() {
  print("testNestedHandlers")
  let arena = UnsafeMutableRawBufferPointer.allocate(byteCount: 4096, alignment: 16)
  defer { arena.deallocate() }
  // Outer: SystemAllocator. Inner: BumpAllocator.
  var sysBuf: UnsafeMutableRawBufferPointer!
  var sysByte: UInt8 = 0
  var bumpBuf: UnsafeMutableRawBufferPointer!
  var bumpByte: UInt8 = 0
  do {
    // This allocation uses SystemAllocator (outer).
    sysBuf = allocateAndWrite(11, byteCount: 8)!
    sysByte = sysBuf[0]

    do {
      // This allocation uses BumpAllocator (inner overrides).
      bumpBuf = allocateAndWrite(22, byteCount: 8)!
      bumpByte = bumpBuf[0]
      deallocateBuffer(bumpBuf)
    } handle BumpAllocator(region: arena) as Allocation

    deallocateBuffer(sysBuf)
  } handle SystemAllocator() as Allocation
  let sysInArena = sysBuf.baseAddress! >= arena.baseAddress! &&
                   sysBuf.baseAddress! < arena.baseAddress! + arena.count
  let bumpInArena = bumpBuf.baseAddress! >= arena.baseAddress! &&
                    bumpBuf.baseAddress! < arena.baseAddress! + arena.count
  // CHECK: outer (system) in arena: false, byte: 11
  print("outer (system) in arena: \(sysInArena), byte: \(sysByte)")
  // CHECK: inner (bump) in arena: true, byte: 22
  print("inner (bump) in arena: \(bumpInArena), byte: \(bumpByte)")
}
testNestedHandlers()

// === Test 5: Existential path (no 'some') ===

func allocateExistential(byteCount: Int) effects(Allocation) -> UnsafeMutableRawBufferPointer? {
  withEffect { (a: inout Allocation) in
    a.allocate(byteCount: byteCount, alignment: 1)
  }
}

// CHECK-LABEL: testExistentialPath
func testExistentialPath() {
  print("testExistentialPath")
  let arena = UnsafeMutableRawBufferPointer.allocate(byteCount: 4096, alignment: 16)
  defer { arena.deallocate() }
  var buf: UnsafeMutableRawBufferPointer!
  do {
    buf = allocateExistential(byteCount: 256)!
    buf[0] = 77
  } handle BumpAllocator(region: arena) as Allocation
  let inArena = buf.baseAddress! >= arena.baseAddress! &&
                buf.baseAddress! < arena.baseAddress! + arena.count
  // CHECK: existential alloc in arena: true, size: 256, first byte: 77
  print("existential alloc in arena: \(inArena), size: \(buf.count), first byte: \(buf[0])")
}
testExistentialPath()

// === Test 6: BumpAllocator OOM returns nil ===

// CHECK-LABEL: testBumpOOM
func testBumpOOM() {
  print("testBumpOOM")
  let arena = UnsafeMutableRawBufferPointer.allocate(byteCount: 128, alignment: 8)
  defer { arena.deallocate() }
  var first: UnsafeMutableRawBufferPointer?
  var second: UnsafeMutableRawBufferPointer?
  var third: UnsafeMutableRawBufferPointer?
  do {
    // First allocation: 64 bytes — fits in 128-byte arena.
    first = withEffect { (a: inout some Allocation) in
      a.allocate(byteCount: 64, alignment: 8)
    }

    // Second allocation: 100 bytes — doesn't fit (64 + 100 > 128).
    second = withEffect { (a: inout some Allocation) in
      a.allocate(byteCount: 100, alignment: 8)
    }

    // Third allocation: 60 bytes — fits in remaining space (128 - 64 = 64 >= 60).
    third = withEffect { (a: inout some Allocation) in
      a.allocate(byteCount: 60, alignment: 8)
    }
  } handle BumpAllocator(region: arena) as Allocation
  // CHECK: first: success
  print("first: \(first != nil ? "success" : "nil")")
  // CHECK: second: nil
  print("second: \(second != nil ? "success" : "nil")")
  // CHECK: third: success
  print("third: \(third != nil ? "success" : "nil")")
}
testBumpOOM()

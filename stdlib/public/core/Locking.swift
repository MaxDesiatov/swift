//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// The effect of acquiring a runtime lock.
///
/// A function declaring `effects(Locking)` may perform operations that lock
/// (for example reference counting) but not operations that allocate. The
/// compiler enforces this through the SIL performance-diagnostics pass; the
/// effect requires no handler.
@_spi(ExperimentalContextEffects)
@_marker public protocol Locking: Effect, ~Copyable, ~Escapable {}

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

/// A marker protocol that identifies a protocol as an "effect protocol."
///
/// Protocols that conform to `Effect` declare a set of operations that
/// represent a side effect. Functions can declare which effects they
/// perform using `performs(EffectName)` clauses, and callers can provide
/// concrete handlers for those effects.
///
///     protocol FileSystem: Effect {
///         mutating func readFile(at path: String) -> String
///     }
///
@_marker public protocol Effect: ~Copyable, ~Escapable {}

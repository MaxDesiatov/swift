@_spi(ExperimentalContextEffects) import Swift

public class C {}

@_spi(ExperimentalContextEffects) public protocol E1: Effect {}
@_spi(ExperimentalContextEffects) public protocol E2: Effect {}

// effects(Never) and effects(Locking) are usable without an SPI import.
public func neverCallee() effects(Never) {}
public func lockingCallee() effects(Locking) {}

// Custom single-protocol and composition rows, to exercise all three row
// shapes through binary serialization.
@_spi(ExperimentalContextEffects) public func e1Callee() effects(E1) {}
@_spi(ExperimentalContextEffects) public func compositionCallee() effects(E1 & E2) {}

// A type whose method carries an effects row, for cross-module witness matching
// under retroactive conformance in the importer.
public struct S {
  public init() {}
  public func m() effects(Never) {}
}


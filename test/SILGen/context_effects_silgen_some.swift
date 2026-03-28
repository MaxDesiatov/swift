// RUN: %target-swift-emit-silgen -enable-experimental-feature ContextEffects %s | %FileCheck %s
// REQUIRES: swift_feature_ContextEffects

protocol FileSystem: Effect {
  mutating func readFile(at path: String) -> String
}
struct MockFS: FileSystem {
  mutating func readFile(at path: String) -> String { "mock: \(path)" }
}

// 'some' path: should produce witness_method on τ_0_0, no init_existential_addr
func readFileSome(at path: String) performs(FileSystem) -> String {
  perform { (fs: inout some FileSystem) in fs.readFile(at: path) }
}

// CHECK-LABEL: sil hidden [ossa] @$s27context_effects_silgen_some12readFileSome2atS2S_tF
// CHECK-NOT: init_existential_addr
// CHECK: witness_method $τ_0_0, #FileSystem.readFile
// CHECK: apply {{%[0-9]+}}<τ_0_0>({{%[0-9]+}}, {{%[0-9]+}})
// CHECK: } // end sil function

// non-'some' path: should produce init_existential_addr (existential bridge)
func readFileExistential(at path: String) performs(FileSystem) -> String {
  perform { (fs: inout FileSystem) in fs.readFile(at: path) }
}

// CHECK-LABEL: sil hidden [ossa] @$s27context_effects_silgen_some19readFileExistential2atS2S_tF
// CHECK: init_existential_addr
// CHECK: } // end sil function

// Multi-statement 'some' closure: should fall back to Path B (init_existential_addr)
func readFileMultiStatement(at path: String) performs(FileSystem) -> String {
  perform { (fs: inout some FileSystem) in
    let _ = fs.readFile(at: "setup.txt")
    return fs.readFile(at: path)
  }
}

// CHECK-LABEL: sil hidden [ossa] @$s27context_effects_silgen_some22readFileMultiStatement2atS2S_tF
// CHECK: init_existential_addr
// CHECK: } // end sil function

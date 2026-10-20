import LeanCompilerBackend.Parser
import LeanCompilerBackend.Verified.Codec

namespace LeanCompilerBackend.Verified.CodecTests

private def require (b : Bool) (message : String) : IO Unit :=
  unless b do throw (IO.userError message)
private def success [Repr ε] (r : Except ε α) : IO α :=
  match r with | .ok a => pure a | .error e => throw (IO.userError s!"{repr e}")
private def failed : Except ε α → Bool
  | .error _ => true | .ok _ => false

private def hashTests : IO Unit := do
  for (text, expected) in [
      ("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
      ("abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
      ("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq", "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1") ] do
    require (SHA256.hex text.toUTF8 == expected) "SHA-256 known-vector mismatch"
  -- Fixed binary and padding-boundary vectors independently calculated by hashlib.
  let inputs := #[0,1,55,56,63,64,65,127,128,129]
  let expected := #[
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d",
    "463eb28e72f82e0a96c0a4cc53690c571281131f672aa229e0d45ae59b598b59", "da2ae4d6b36748f2a318f23e7ab1dfdf45acdc9d049bd80e59de82a60895f562", "29af2686fd53374a36b0846694cc342177e428d1647515f078784d69cdb9e488", "fdeab9acf3710362bd2658cdc9a29e8f9c757fcf9811603a8c447cd1d9151108", "4bfd2c8b6f1eec7a2afeb48b934ee4b2694182027e6d0fc075074f2fabb31781",
    "92ca0fa6651ee2f97b884b7246a562fa71250fedefe5ebf270d31c546bfea976", "471fb943aa23c511f6f72f8d1652d9c880cfa392ad80503120547703e56a2be5", "5099c6a56203f9687f7d33f4bfdf576d31dc91f6b695ecea38b2770c87631135"]
  for i in [:inputs.size] do
    let bytes := ByteArray.mk ((Array.range inputs[i]!).map (·.toUInt8))
    require (SHA256.hex bytes == expected[i]!) "SHA-256 binary/padding boundary mismatch"

private def codecTests : IO Unit := do
  let parsed ← success (Parser.parse "export function l $f(w %n,l %x) { @s jmp @b @b %v =l phi @s %x %r =l add %v, -1 ret %r }")
  let some f := parsed[0]? | throw (IO.userError "missing function")
  let job ← success (prepareJob f "codec-tests")
  let bytes ← success (Codec.encodeJob job)
  let decoded ← success (Codec.decodeJob bytes)
  require (decide (job = decoded)) "job roundtrip changed value"
  require ((← success (Codec.encodeJob decoded)) == bytes) "job roundtrip changed bytes"
  let artifact ← success (compileFunction decoded)
  let packet ← success (Codec.encodeArtifact job artifact)
  let (replayedJob, replayed) ← success (Codec.decodeArtifact packet)
  require (decide (job = replayedJob ∧ artifact = replayed)) "artifact replay mismatch"
  for cut in [0,1,8,16,bytes.size-1] do
    require (failed (Codec.decodeJob (bytes.extract 0 cut))) "truncated job accepted"
  require (failed (Codec.decodeJob (bytes.push 0))) "trailing job byte accepted"
  -- Packet: LE64 kind length, UTF-8 kind, then LE64 packet version.
  let versionAt := 8 + "LCB-job".toUTF8.size
  require (failed (Codec.decodeJob (bytes.set! versionAt 2))) "unknown wire version accepted"
  let corruptLength := (List.range 8).foldl (fun b i => b.set! i 255) bytes
  require (failed (Codec.decodeJob corruptLength)) "hostile string length accepted"
  require (failed (Codec.decodeJob (bytes.set! 8 255))) "invalid UTF-8 accepted"
  require (failed (Codec.decodeArtifact (packet.extract 0 (packet.size-1)))) "truncated artifact accepted"
  require (failed (Codec.decodeArtifact (packet.push 0))) "trailing artifact byte accepted"
  require (failed (Codec.decodeArtifact (packet.set! (packet.size-1) 255))) "artifact evidence corruption accepted"
  let checks ← success (Codec.fingerprints artifact)
  let debugJob := { job with debug := {
    sources := #[{ id := 0, logicalPath := "src/f.qbe", contentIdentity := "new-source" }]
    origins := #[{ block := 1, kind := 1, index := 0, source := 0, line := 9, column := 2 }] } }
  let debugArtifact ← success (compileFunction debugJob)
  let debugIds ← success (Codec.fingerprints debugArtifact)
  require (checks.codeInput == debugIds.codeInput && checks.code == debugIds.code &&
    checks.evidence == debugIds.evidence && checks.debug != debugIds.debug)
    "debug dependency separation failed"
  let evidenceArtifact ← success (compileFunction { job with proof.libraryIdentity := "other-library" })
  let evidenceIds ← success (Codec.fingerprints evidenceArtifact)
  require (checks.codeInput == evidenceIds.codeInput && checks.code == evidenceIds.code &&
    checks.debug == evidenceIds.debug && checks.evidence != evidenceIds.evidence)
    "evidence dependency separation failed"
  let substituted ← success (Codec.encodeArtifact debugJob debugArtifact)
  require (substituted != packet) "different debug dependency produced identical envelope"
  require (failed (Codec.decodeArtifactFor job substituted)) "cache lookup accepted another complete job"
  let _ ← success (Codec.decodeArtifactFor debugJob substituted)
  let proofJob := { job with requested := .kernelTypedAssembly }
  let proofBytes ← success (Codec.encodeJob proofJob)
  let proofDecoded ← success (Codec.decodeJob proofBytes)
  require (proofDecoded.requested == .kernelTypedAssembly) "codec downgraded request"
  require (failed (compileFunction proofDecoded)) "replayed proof request silently accepted"
  let maxProfile := { job with proof.allowedAxioms := Array.replicate 64 "propext" }
  let maxBytes ← success (Codec.encodeJob maxProfile)
  require (decide ((← success (Codec.decodeJob maxBytes)) = maxProfile))
    "maximum proof-profile collection did not roundtrip"
  let oversizedProfile := { job with proof.allowedAxioms := Array.replicate 65 "propext" }
  require (failed (Codec.encodeJob oversizedProfile))
    "encoder accepted a proof-profile collection the decoder rejects"
  let oversizedArtifact ← success (compileFunction oversizedProfile)
  require (failed (Codec.identities oversizedArtifact)) "oversized proof-profile identity accepted"
  let large := String.ofList (List.replicate 4097 'a')
  require (failed (Codec.encodeJob { job with code.symbol.namespaceName := large })) "oversized encoded string accepted"
  -- Primitive decoders reject noncanonical booleans/tags before constructing jobs.
  require (failed (Wire.decode Wire.readBoolean (ByteArray.mk #[2]))) "invalid boolean accepted"
  require (failed (Wire.encode (Wire.natural (2^64)))) "wire integer truncation"

def run : IO Unit := do
  hashTests
  codecTests
  IO.println "canonical job/artifact replay, dependency identities and SHA-256 checks passed"

end LeanCompilerBackend.Verified.CodecTests

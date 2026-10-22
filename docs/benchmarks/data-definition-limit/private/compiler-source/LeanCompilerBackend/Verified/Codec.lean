/- Versioned job codec and replay envelopes. Exact canonical bytes bind every
   product; hashes, when available, are indices only. No preservation evidence. -/
import LeanCompilerBackend.Verified.Wire
import LeanCompilerBackend.Verified.SHA256

namespace LeanCompilerBackend.Verified.Codec
open Wire

private def width (w : Width) : Encoder Unit := byte (if w == .word then 0 else 1)
private def readWidth : Decoder Width := do
  match ← readByte with | 0 => pure .word | 1 => pure .long | _ => throw "unknown width tag"

private def value (v : Source.Value) : Encoder Unit := do
  width v.width
  for i in [:v.width.bytes] do byte ((v.toNat / 2^(8*i)) % 256)
private def readValue : Decoder Source.Value := do
  let w ← readWidth
  let mut n := 0
  for i in [:w.bytes] do n := n + (← readByte) * 2^(8*i)
  pure (Source.Value.constant w n)

private def operand : Source.Operand → Encoder Unit
  | .local id => do byte 0; natural id
  | .literal v => do byte 1; value v
private def readOperand : Decoder Source.Operand := do
  match ← readByte with
  | 0 => pure (.local (← readNatural))
  | 1 => pure (.literal (← readValue))
  | _ => throw "unknown operand tag"

private def binary (op : Source.Binary) : Encoder Unit := byte (match op with
  | .add => 0 | .sub => 1 | .mul => 2 | .andBits => 3 | .orBits => 4 | .xorBits => 5)
private def readBinary : Decoder Source.Binary := do
  match ← readByte with
  | 0 => pure .add | 1 => pure .sub | 2 => pure .mul
  | 3 => pure .andBits | 4 => pure .orBits | 5 => pure .xorBits
  | _ => throw "unknown binary opcode"
private def comparison (op : Source.Comparison) : Encoder Unit := byte (if op == .eq then 0 else 1)
private def readComparison : Decoder Source.Comparison := do
  match ← readByte with | 0 => pure .eq | 1 => pure .unsignedLT | _ => throw "unknown comparison"

private def operation : Source.Operation → Encoder Unit
  | .copy v => do byte 0; operand v
  | .binary op lhs rhs => do byte 1; binary op; operand lhs; operand rhs
  | .compare op w lhs rhs => do byte 2; comparison op; width w; operand lhs; operand rhs
private def readOperation : Decoder Source.Operation := do
  match ← readByte with
  | 0 => pure (.copy (← readOperand))
  | 1 => pure (.binary (← readBinary) (← readOperand) (← readOperand))
  | 2 => pure (.compare (← readComparison) (← readWidth) (← readOperand) (← readOperand))
  | _ => throw "unknown source operation"

private def instruction (i : Source.Instruction) : Encoder Unit := do
  natural i.destination; width i.width; operation i.operation
private def readInstruction : Decoder Source.Instruction := do
  let destination ← readNatural
  let w ← readWidth
  pure { destination, width := w, operation := ← readOperation }

private def phi (p : Source.Phi) : Encoder Unit := do
  natural p.destination; width p.width
  array (fun (pred, v) => do natural pred; operand v) p.incoming
private def readPhi : Decoder Source.Phi := do
  let destination ← readNatural
  let w ← readWidth
  let incoming ← readArray 64 (do pure (← readNatural, ← readOperand))
  pure { destination, width := w, incoming }

private def terminator : Source.Terminator → Encoder Unit
  | .ret v => do byte 0; operand v
  | .jump target => do byte 1; natural target
  | .branch v yes no => do byte 2; operand v; natural yes; natural no
private def readTerminator : Decoder Source.Terminator := do
  match ← readByte with
  | 0 => pure (.ret (← readOperand))
  | 1 => pure (.jump (← readNatural))
  | 2 => pure (.branch (← readOperand) (← readNatural) (← readNatural))
  | _ => throw "unknown terminator"

private def source (f : Source.Function) : Encoder Unit := do
  width f.resultWidth
  array width f.parameters
  array width f.valueWidths
  array (fun b => do array phi b.phis; array instruction b.instructions; terminator b.terminator) f.blocks
private def readSource : Decoder Source.Function := do
  let resultWidth ← readWidth
  let parameters ← readArray 8 readWidth
  let valueWidths ← readArray 488 readWidth
  let blocks ← readArray 64 do
    let phis ← readArray 480 readPhi
    let instructions ← readArray 480 readInstruction
    pure { phis, instructions, terminator := ← readTerminator : Source.Block }
  pure { resultWidth, parameters, valueWidths, blocks }

private def abi (p : AbiPlan) : Encoder Unit := do
  natural p.version; string p.profile
  array (fun (w, r) => do width w; natural r) p.parameters
  width p.result.1; natural p.result.2
  natural p.stackAlignment; natural p.incomingStackBytes; natural p.outgoingStackBytes
  array natural p.clobbered; array natural p.preserved
  boolean p.wordInputHighBitsUnconstrained; boolean p.wordResultHighBitsZero
  boolean p.writesFlags; boolean p.restoresSP
private def readAbi : Decoder AbiPlan := do
  let version ← readNatural
  let profile ← readString
  let parameters ← readArray 8 (do pure (← readWidth, ← readNatural))
  let result := (← readWidth, ← readNatural)
  let stackAlignment ← readNatural
  let incomingStackBytes ← readNatural
  let outgoingStackBytes ← readNatural
  let clobbered ← readArray 31 readNatural
  let preserved ← readArray 31 readNatural
  let wordInputHighBitsUnconstrained ← readBoolean
  let wordResultHighBitsZero ← readBoolean
  let writesFlags ← readBoolean
  let restoresSP ← readBoolean
  pure { version, profile, parameters, result, stackAlignment, incomingStackBytes, outgoingStackBytes,
         clobbered, preserved, wordInputHighBitsUnconstrained, wordResultHighBitsZero, writesFlags, restoresSP }

private def layout (l : FrameLayout) : Encoder Unit := do
  natural l.version; array natural l.valueOffsets; array natural l.stageOffsets; natural l.frameBytes
private def readLayout : Decoder FrameLayout := do
  let version ← readNatural
  let valueOffsets ← readArray 488 readNatural
  let stageOffsets ← readArray 480 readNatural
  pure { version, valueOffsets, stageOffsets, frameBytes := ← readNatural }

private def codeInput (c : CodeInput) : Encoder Unit := do
  natural c.version; string c.sourceSemantics; string c.targetSemantics
  string c.target; string c.pipeline; string c.compilerRevision; string c.compilerBuild
  string c.symbol.namespaceName; string c.symbol.name; boolean c.symbol.exported
  source c.body; abi c.abi; layout c.layout
  array string c.imports; array string c.consumedFacts
private def readCodeInput : Decoder CodeInput := do
  let version ← readNatural
  let sourceSemantics ← readString
  let targetSemantics ← readString
  let target ← readString
  let pipeline ← readString
  let compilerRevision ← readString
  let compilerBuild ← readString
  let namespaceName ← readString
  let name ← readString
  let exported ← readBoolean
  let body ← readSource
  let abi ← readAbi
  let layout ← readLayout
  let imports ← readArray 0 readString
  let consumedFacts ← readArray 0 readString
  pure { version, sourceSemantics, targetSemantics, target, pipeline, compilerRevision, compilerBuild,
         symbol := { namespaceName, name, exported }, body, abi, layout, imports, consumedFacts }

private def debugInput (d : DebugInput) : Encoder Unit := do
  array (fun s => do natural s.id; string s.logicalPath; string s.contentIdentity) d.sources
  array (fun o => do natural o.block; natural o.kind; natural o.index; natural o.source; natural o.line; natural o.column) d.origins
private def readDebugInput : Decoder DebugInput := do
  let sources ← readArray 1024 do
    let id ← readNatural
    let logicalPath ← readString
    pure { id, logicalPath, contentIdentity := ← readString : DebugSource }
  let origins ← readArray 1024 do
    let block ← readNatural
    let kind ← readNatural
    let index ← readNatural
    let source ← readNatural
    let line ← readNatural
    pure { block, kind, index, source, line, column := ← readNatural : DebugOrigin }
  pure { sources, origins }

private def proofProfile (p : ProofProfile) : Encoder Unit := do
  if p.allowedAxioms.size > 64 then throw "proof axiom list exceeds 64 entries"
  string p.libraryIdentity; string p.leanVersion; array string p.allowedAxioms
private def readProofProfile : Decoder ProofProfile := do
  let libraryIdentity ← readString
  let leanVersion ← readString
  pure { libraryIdentity, leanVersion, allowedAxioms := ← readArray 64 readString }

private def request (r : EvidenceRequest) : Encoder Unit := byte (match r with
  | .none => 0 | .kernelTypedAssembly => 1 | .nativeBinary => 2)
private def readRequest : Decoder EvidenceRequest := do
  match ← readByte with
  | 0 => pure .none | 1 => pure .kernelTypedAssembly | 2 => pure .nativeBinary
  | _ => throw "unknown evidence request"

private def job (j : FunctionJob) : Encoder Unit := do
  codeInput j.code; debugInput j.debug; request j.requested; proofProfile j.proof
private def readJob : Decoder FunctionJob := do
  let code ← readCodeInput
  let debug ← readDebugInput
  let requested ← readRequest
  pure { code, debug, requested, proof := ← readProofProfile }

private def header (kind : String) : Encoder Unit := do string kind; natural 1
private def readHeader (kind : String) : Decoder Unit := do
  if (← readString 32) != kind then throw "wrong packet kind"
  if (← readNatural) != 1 then throw "unknown packet version"

def encodeJob (j : FunctionJob) : Except String ByteArray := do
  (validateJob j).mapError (fun e => toString (repr e))
  encode (do header "LCB-job"; job j)

def decodeJob (input : ByteArray) : Except String FunctionJob := do
  let j ← decode (do readHeader "LCB-job"; readJob) input
  (validateJob j).mapError (fun e => toString (repr e))
  let canonical ← encodeJob j
  if canonical != input then throw "noncanonical job encoding"
  pure j

private def label : StackMIR.Label → Encoder Unit
  | .entry => byte 0
  | .body id => do byte 1; natural id
  | .edge pred target => do byte 2; natural pred; natural target
private def reg (r : StackMIR.Register) : Encoder Unit := byte (match r with | .r0 => 0 | .r9 => 1 | .r10 => 2)
private def slot : StackMIR.Slot → Encoder Unit
  | .value id => do byte 0; natural id
  | .stage id => do byte 1; natural id
private def mirInstruction : StackMIR.Instruction → Encoder Unit
  | .enterFrame n => do byte 0; natural n
  | .leaveFrame n => do byte 1; natural n
  | .readArg w i s => do byte 2; width w; natural i; slot s
  | .constant r v => do byte 3; reg r; value v
  | .load w r s => do byte 4; width w; reg r; slot s
  | .store w s r => do byte 5; width w; slot s; reg r
  | .alu w op d a b => do byte 6; width w; binary op; reg d; reg a; reg b
  | .compare w op d a b => do byte 7; width w; comparison op; reg d; reg a; reg b
private def mir (f : StackMIR.Function) : Encoder Unit := do
  array width f.parameters; width f.resultWidth; array width f.valueWidths; layout f.layout
  array (fun b => do
    label b.label; array mirInstruction b.instructions
    match b.terminator with
    | .jump t => do byte 0; label t
    | .branch c y n => do byte 1; reg c; label y; label n
    | .ret w => do byte 2; width w) f.blocks
private def assemblyInstruction : TypedA64.Instruction → Encoder Unit
  | .subSP n => do byte 0; natural n
  | .addSP n => do byte 1; natural n
  | .load w r o => do byte 2; width w; natural r; natural o
  | .store w r o => do byte 3; width w; natural r; natural o
  | .movz w r c s => do byte 4; width w; natural r; natural c; natural s
  | .movk w r c s => do byte 5; width w; natural r; natural c; natural s
  | .alu w op d a b => do byte 6; width w; binary op; natural d; natural a; natural b
  | .cmp w a b => do byte 7; width w; natural a; natural b
  | .cset r c => do byte 8; natural r; byte (if c == .eq then 0 else 1)
  | .cbnz r t => do byte 9; natural r; label t
  | .jump t => do byte 10; label t
  | .ret => byte 11
private def assembly (f : TypedA64.Function) : Encoder Unit := do
  array width f.parameters; width f.resultWidth; natural f.frameBytes
  array (fun b => do label b.label; array assemblyInstruction b.instructions) f.blocks

/-- These exact canonical byte sequences are the binding identities. A future
    digest index may accelerate lookup but must not replace exact comparison. -/
structure Identities where
  codeInput : ByteArray
  code : ByteArray
  debug : ByteArray
  evidence : ByteArray

def identities (artifact : FunctionArtifact) : Except String Identities := do
  if artifact.version != 1 || artifact.debug.code != artifact.code then
    throw "invalid artifact version or debug/code binding"
  let input ← encode (do header "LCB-code-input"; codeInput artifact.code.input)
  let code ← encode do
    header "LCB-code"; bytes input; mir artifact.code.stackMIR
    assembly artifact.code.assembly; bytes artifact.code.fragment.toUTF8
  let debug ← encode (do header "LCB-debug"; bytes code; debugInput artifact.debug.input)
  let evidence ← encode do
    header "LCB-evidence"; bytes code; proofProfile artifact.proofProfile
    match artifact.verification with
    | .uncertified checks => byte 0; array string checks
  pure { codeInput := input, code, debug, evidence }

structure Fingerprints where
  codeInput : String
  code : String
  debug : String
  evidence : String
  deriving DecidableEq, Repr

def fingerprints (a : FunctionArtifact) : Except String Fingerprints := do
  let ids ← identities a
  pure { codeInput := SHA256.hex ids.codeInput, code := SHA256.hex ids.code,
         debug := SHA256.hex ids.debug, evidence := SHA256.hex ids.evidence }

/-- Replay envelope carries the job and every canonical output product. Decode
    reconstructs via the pure baseline then compares bytes; it does not execute
    or trust cached assembly, or claim a semantic certificate. -/
def encodeArtifact (j : FunctionJob) (a : FunctionArtifact) : Except String ByteArray := do
  (verifyArtifact j a).mapError (fun e => toString (repr e))
  let jobBytes ← encodeJob j
  let ids ← identities a
  encode (do header "LCB-artifact"; bytes jobBytes; bytes ids.code; bytes ids.debug; bytes ids.evidence)

def decodeArtifact (input : ByteArray) : Except String (FunctionJob × FunctionArtifact) := do
  let (jobBytes, code, debug, evidence) ← decode (do
    readHeader "LCB-artifact"
    pure (← readBytes 1048576, ← readBytes 1048576, ← readBytes 1048576, ← readBytes 1048576)) input
  let j ← decodeJob jobBytes
  let artifact ← (compileFunction j).mapError (fun e => toString (repr e))
  let expected ← identities artifact
  if code != expected.code || debug != expected.debug || evidence != expected.evidence then
    throw "artifact product/input/evidence binding mismatch"
  pure (j, artifact)

/-- Cache consumers have an independently requested job. Decoding an envelope
    alone is replay, not proof that it is the requested cache entry. -/
def decodeArtifactFor (expected : FunctionJob) (input : ByteArray) : Except String FunctionArtifact := do
  let (job, artifact) ← decodeArtifact input
  if job != expected then throw "cached artifact belongs to a different requested job"
  (verifyArtifact expected artifact).mapError (fun e => toString (repr e))
  pure artifact

end LeanCompilerBackend.Verified.Codec

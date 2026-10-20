/- Frame-byte reconstruction and preservation for actual target load/store helpers. -/
import LeanCompilerBackend.Verified.Machine

namespace LeanCompilerBackend.Verified.Machine

theorem writeBytes_size (count start : Nat) (value : UInt64) (memory : Array (Option UInt8)) :
    (writeBytes count start value memory).size = memory.size := by
  induction count generalizing start value memory with
  | zero => rfl
  | succ count ih => simp [writeBytes, ih]

/-- Bytes outside the written half-open interval are unchanged, including
    initialization status. No assumption about their old contents is needed. -/
theorem writeBytes_outside (count start index : Nat) (value : UInt64)
    (memory : Array (Option UInt8)) (outside : index < start ∨ start+count ≤ index) :
    (writeBytes count start value memory)[index]? = memory[index]? := by
  induction count generalizing start value memory with
  | zero => rfl
  | succ count ih =>
    have different : start ≠ index := by omega
    have rest : index < start+1 ∨ start+1+count ≤ index := by omega
    rw [writeBytes, ih (start+1) (value >>> 8) (memory.set! start (some value.toUInt8)) rest]
    simp [Array.getElem?_setIfInBounds_ne different]

/-- Every byte of an in-bounds store is initialized afterward. -/
theorem writeBytes_initializes (count start index : Nat) (value : UInt64)
    (memory : Array (Option UInt8)) (bounds : start+count ≤ memory.size)
    (inside : start ≤ index ∧ index < start+count) :
    ∃ byte, (writeBytes count start value memory)[index]? = some (some byte) := by
  induction count generalizing start value memory with
  | zero => omega
  | succ count ih =>
    by_cases first : index = start
    · subst index
      rw [writeBytes, writeBytes_outside count (start+1) start (value >>> 8)
        (memory.set! start (some value.toUInt8)) (Or.inl (by omega))]
      refine ⟨value.toUInt8, ?_⟩
      simp [Array.getElem?_setIfInBounds_self_of_lt (show start < memory.size by omega)]
    · have rest : start+1 ≤ index ∧ index < start+1+count := by omega
      have space : start+1+count ≤ (memory.set! start (some value.toUInt8)).size := by
        simp only [Array.set!_eq_setIfInBounds, Array.size_setIfInBounds]
        omega
      exact ih (start+1) (value >>> 8) (memory.set! start (some value.toUInt8)) space rest

/-- Byte `index` in little-endian order, without referring to frame memory. -/
def littleEndianByte : Nat → UInt64 → UInt8
  | 0, value => value.toUInt8
  | index+1, value => littleEndianByte index (value >>> 8)

/-- A store writes the exact corresponding little-endian byte, independently
    of the previous contents and of the rest of the frame. -/
theorem writeBytes_byte (count start index : Nat) (value : UInt64)
    (memory : Array (Option UInt8)) (bounds : start+count ≤ memory.size)
    (inside : index < count) :
    (writeBytes count start value memory)[start+index]? =
      some (some (littleEndianByte index value)) := by
  induction count generalizing start index value memory with
  | zero => omega
  | succ count ih =>
    cases index with
    | zero =>
      simp only [Nat.add_zero]
      rw [writeBytes, writeBytes_outside count (start+1) start (value >>> 8)
        (memory.set! start (some value.toUInt8)) (Or.inl (by omega))]
      simp [littleEndianByte, Array.getElem?_setIfInBounds_self_of_lt (show start < memory.size by omega)]
    | succ index =>
      have space : start+1+count ≤ (memory.set! start (some value.toUInt8)).size := by
        simp only [Array.set!_eq_setIfInBounds, Array.size_setIfInBounds]
        omega
      have rest := ih (start+1) index (value >>> 8)
        (memory.set! start (some value.toUInt8)) space (by omega)
      simpa only [writeBytes, littleEndianByte, Nat.add_assoc, Nat.add_comm 1 index] using rest

/-- Reading a just-written span reconstructs exactly its low bytes. This
    theorem uses the actual read/write helpers and arbitrary old frame bytes. -/
theorem readBytes_writeBytes (count start : Nat) (value : UInt64)
    (memory : Array (Option UInt8)) (bounds : start+count ≤ memory.size) :
    readBytes count start (writeBytes count start value memory) =
      .ok (value.toNat % 256^count) := by
  induction count generalizing start value memory with
  | zero => simp [readBytes, Nat.mod_one]
  | succ count ih =>
    have first : (writeBytes count (start+1) (value >>> 8)
        (memory.set! start (some value.toUInt8)))[start]? = some (some value.toUInt8) := by
      rw [writeBytes_outside count (start+1) start (value >>> 8)
        (memory.set! start (some value.toUInt8)) (Or.inl (by omega))]
      simp [Array.getElem?_setIfInBounds_self_of_lt (show start < memory.size by omega)]
    have space : start+1+count ≤ (memory.set! start (some value.toUInt8)).size := by
      simp only [Array.set!_eq_setIfInBounds, Array.size_setIfInBounds]
      omega
    rw [writeBytes, readBytes, first]
    rw [ih (start+1) (value >>> 8) (memory.set! start (some value.toUInt8)) space]
    simp only [bind, Except.bind, pure, Except.pure]
    congr 1
    simp only [UInt64.toNat_toUInt8, UInt64.toNat_shiftRight, UInt64.reduceToNat,
      Nat.reduceMod, Nat.shiftRight_eq_div_pow, Nat.reducePow]
    rw [Nat.pow_succ, Nat.mul_comm (256^count) 256, Nat.mod_mul]

/-- Reads depend only on the requested byte span, including initialization. -/
theorem readBytes_congr (count start : Nat) (a b : Array (Option UInt8))
    (equal : ∀ i, i < count → a[start+i]? = b[start+i]?) :
    readBytes count start a = readBytes count start b := by
  induction count generalizing start with
  | zero => rfl
  | succ count ih =>
    have first := equal 0 (by omega)
    simp only [Nat.add_zero] at first
    have rest : ∀ i, i < count → a[start+1+i]? = b[start+1+i]? := by
      intro i hi
      have h := equal (i+1) (by omega)
      simpa only [Nat.add_assoc, Nat.add_comm 1 i] using h
    simp only [readBytes, first, ih (start+1) rest]

/-- A disjoint write cannot change either a read's value or its failure from
    uninitialized memory. This applies to unequal access widths as well. -/
theorem readBytes_writeBytes_disjoint (readCount readStart writeCount writeStart : Nat)
    (value : UInt64) (memory : Array (Option UInt8))
    (disjoint : readStart+readCount ≤ writeStart ∨ writeStart+writeCount ≤ readStart) :
    readBytes readCount readStart (writeBytes writeCount writeStart value memory) =
      readBytes readCount readStart memory := by
  apply readBytes_congr
  intro i hi
  apply writeBytes_outside
  omega

/-- Inside an available active frame, SP-relative offsets identify exactly the
    corresponding owned-array bytes; no wrapping or external access is hidden. -/
theorem address_in_frame (d : Data) (width : Width) (offset : Nat)
    (active : d.active = true) (space : d.frameBytes ≤ d.entrySP)
    (sp : d.sp = d.entrySP - d.frameBytes) (memory : d.memory.size = d.frameBytes)
    (access : offset + width.bytes ≤ d.frameBytes) (nowrap : d.entrySP < 2^64) :
    address d width offset = .ok offset := by
  have lower : ¬d.sp + offset < d.entrySP - d.frameBytes := by omega
  have upper : ¬d.sp + offset + width.bytes > d.entrySP := by omega
  have wrap : ¬d.sp + offset + width.bytes > 2^64 := by omega
  have translate : d.sp + offset - (d.entrySP - d.frameBytes) = offset := by omega
  simp [address, active, Nat.not_lt.mpr space, lower, upper, wrap, memory, translate]
  rfl

/-- The actual store executes the proved byte-span helper at the planned offset. -/
theorem store_in_frame (d : Data) (width : Width) (offset : Nat) (value : UInt64)
    (active : d.active = true) (space : d.frameBytes ≤ d.entrySP)
    (sp : d.sp = d.entrySP - d.frameBytes) (memory : d.memory.size = d.frameBytes)
    (access : offset + width.bytes ≤ d.frameBytes) (nowrap : d.entrySP < 2^64) :
    store d width offset value =
      .ok { d with memory := writeBytes width.bytes offset value d.memory } := by
  simp [store, address_in_frame d width offset active space sp memory access nowrap, bind, Except.bind]
  rfl

/-- Actual target stores followed by same-width loads return the width-normalized
    value, including zero extension of word loads. -/
theorem load_store_same (d : Data) (width : Width) (offset : Nat) (value : UInt64)
    (active : d.active = true) (space : d.frameBytes ≤ d.entrySP)
    (sp : d.sp = d.entrySP - d.frameBytes) (memory : d.memory.size = d.frameBytes)
    (access : offset + width.bytes ≤ d.frameBytes) (nowrap : d.entrySP < 2^64) :
    (store d width offset value >>= fun updated => load updated width offset) =
      .ok (normalize width value) := by
  rw [store_in_frame d width offset value active space sp memory access nowrap]
  simp only [bind, Except.bind]
  let updated := { d with memory := writeBytes width.bytes offset value d.memory }
  have memory' : updated.memory.size = d.frameBytes := by
    simp [updated, writeBytes_size, memory]
  rw [load, address_in_frame updated width offset active space sp memory' access nowrap]
  simp only [bind, Except.bind]
  rw [readBytes_writeBytes width.bytes offset value d.memory (by omega)]
  simp only [pure, Except.pure]
  congr 1
  apply UInt64.toNat_inj.mp
  cases width <;> simp [Width.bytes, Width.bits, normalize]
  omega

/-- The actual load result is unchanged by a disjoint in-frame store. Registers,
    SP and the initialized/uninitialized status of the read span are preserved. -/
theorem load_store_disjoint (d : Data) (readWidth writeWidth : Width)
    (readOffset writeOffset : Nat) (value : UInt64)
    (active : d.active = true) (space : d.frameBytes ≤ d.entrySP)
    (sp : d.sp = d.entrySP - d.frameBytes) (memory : d.memory.size = d.frameBytes)
    (readAccess : readOffset + readWidth.bytes ≤ d.frameBytes)
    (writeAccess : writeOffset + writeWidth.bytes ≤ d.frameBytes)
    (nowrap : d.entrySP < 2^64)
    (disjoint : readOffset+readWidth.bytes ≤ writeOffset ∨
      writeOffset+writeWidth.bytes ≤ readOffset) :
    (store d writeWidth writeOffset value >>= fun updated => load updated readWidth readOffset) =
      load d readWidth readOffset := by
  rw [store_in_frame d writeWidth writeOffset value active space sp memory writeAccess nowrap]
  simp only [bind, Except.bind]
  let updated := { d with memory := writeBytes writeWidth.bytes writeOffset value d.memory }
  have memory' : updated.memory.size = d.frameBytes := by
    simp [updated, writeBytes_size, memory]
  simp only [load]
  rw [address_in_frame updated readWidth readOffset active space sp memory' readAccess nowrap,
    address_in_frame d readWidth readOffset active space sp memory readAccess nowrap]
  simp only [bind, Except.bind]
  rw [readBytes_writeBytes_disjoint readWidth.bytes readOffset writeWidth.bytes writeOffset value d.memory disjoint]

end LeanCompilerBackend.Verified.Machine

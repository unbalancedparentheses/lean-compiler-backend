/- Arithmetic facts about the actual stack plan. These are ingredients for the
   byte-memory simulation, not a proof that lowering preserves source behavior. -/
import LeanCompilerBackend.Verified.Plans

namespace LeanCompilerBackend.Verified

def phiCapacity (f : Source.Function) : Nat :=
  f.blocks.foldl (fun count block => max count block.phis.size) 0

theorem value_offset (f : Source.Function) (i : Nat) (hi : i < f.valueWidths.size) :
    (planFrame f).valueOffsets[i]? = some (8*i) := by
  change ((Array.range f.valueWidths.size).map (8 * ·))[i]? = _
  simp [hi]

theorem stage_offset (f : Source.Function) (i : Nat) (hi : i < phiCapacity f) :
    (planFrame f).stageOffsets[i]? = some (8*(f.valueWidths.size+i)) := by
  change ((Array.range (phiCapacity f)).map (fun j => 8*(f.valueWidths.size+j)))[i]? = _
  simp [hi]

theorem frame_aligned (f : Source.Function) : (planFrame f).frameBytes % 16 = 0 := by
  change (((8*(f.valueWidths.size + phiCapacity f) + 15)/16)*16)%16 = 0
  omega

theorem frame_covers_slots (f : Source.Function) :
    8*(f.valueWidths.size + phiCapacity f) ≤ (planFrame f).frameBytes := by
  change 8*(f.valueWidths.size + phiCapacity f) ≤ ((8*(f.valueWidths.size + phiCapacity f)+15)/16)*16
  omega

private theorem width_bytes_le_eight (width : Width) : width.bytes ≤ 8 := by
  cases width <;> decide

theorem slot_aligned (width : Width) (i : Nat) : (8*i) % width.bytes = 0 := by
  cases width <;> simp [Width.bytes, Width.bits, Nat.mul_mod]

/-- Half-open byte spans of distinct eight-byte slots cannot overlap. -/
theorem distinct_slots_disjoint (i j : Nat) (wi wj : Width) (different : i ≠ j) :
    8*i + wi.bytes ≤ 8*j ∨ 8*j + wj.bytes ≤ 8*i := by
  have hi := width_bytes_le_eight wi
  have hj := width_bytes_le_eight wj
  omega

theorem value_stage_disjoint (f : Source.Function) (i j : Nat) (width : Width)
    (hi : i < f.valueWidths.size) :
    8*i + width.bytes ≤ 8*(f.valueWidths.size+j) := by
  have h := width_bytes_le_eight width
  omega

theorem value_access_in_frame (f : Source.Function) (i : Nat) (width : Width)
    (hi : i < f.valueWidths.size) : 8*i + width.bytes ≤ (planFrame f).frameBytes := by
  have capacity := frame_covers_slots f
  have bytes := width_bytes_le_eight width
  omega

theorem stage_access_in_frame (f : Source.Function) (i : Nat) (width : Width)
    (hi : i < phiCapacity f) :
    8*(f.valueWidths.size+i) + width.bytes ≤ (planFrame f).frameBytes := by
  have capacity := frame_covers_slots f
  have bytes := width_bytes_le_eight width
  omega

/-- The stricter frame cap implies the ISA's unsigned scaled 12-bit bound. -/
theorem scaled_offset_encodable (f : Source.Function) (offset : Nat) (width : Width)
    (access : offset + width.bytes ≤ (planFrame f).frameBytes)
    (bound : (planFrame f).frameBytes ≤ 4080) : offset / width.bytes < 4096 := by
  have division := Nat.div_le_self offset width.bytes
  omega

end LeanCompilerBackend.Verified

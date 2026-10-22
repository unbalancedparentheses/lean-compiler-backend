import LeanCompilerBackend.IR

/- Bounded custom-section grammars, checked independently for each object format. -/
namespace LeanCompilerBackend.Section

private def nameChar (c : Char) : Bool :=
  c.isAlphanum && c.toNat < 128 || c == '_' || c == '.' || c == '$'

def checkELF (customSection : SectionSpec) : Except String Unit := do
  let name := customSection.name
  if name.isEmpty || name.utf8ByteSize > 128 ||
      !name.toList.all (fun c => 32 <= c.toNat && c.toNat <= 126) then
    throw "ELF section requires 1..128 printable ASCII name bytes"
  if let some flags := customSection.flags then
    if !flags.toList.all (fun c => c == 'a' || c == 'w' || c == 'x' || c == 'R') then
      throw "unsupported ELF section flags (accepted: a, w, x, R)"

def checkApple (customSection : SectionSpec) : Except String Unit := do
  -- Preserve the established LCB Mach-O convention: the two fields form a
  -- validated segment,section[,type[,attributes]] directive without quotes.
  -- This deliberately differs from QBE's literal second-field quote bytes.
  let combined := customSection.name ++ (customSection.flags.map ("," ++ ·)).getD ""
  let parts := combined.splitOn ","
  if parts.length < 2 || parts.length > 4 then
    throw "Apple section requires segment,section[,type[,attributes]]"
  for name in parts.take 2 do
    if name.isEmpty || name.utf8ByteSize > 16 || !name.toList.all (fun c => nameChar c || c == '-') then
      throw "Apple section names must contain 1..16 ASCII name characters"
  if let some kind := parts[2]? then
    if !["regular", "cstring_literals", "4byte_literals", "8byte_literals", "16byte_literals",
        "literal_pointers", "mod_init_funcs", "mod_term_funcs", "coalesced"].contains kind then
      throw "unsupported Apple section type"
  if let some attributes := parts[3]? then
    for attr in attributes.splitOn "+" do
      if !["pure_instructions", "some_instructions", "no_dead_strip", "live_support"].contains attr then
        throw "unsupported Apple section attribute"

/-- Target-independent admission accepts either bounded grammar. The original string
    boundary is retained for ELF; Apple keeps the established combined syntax. -/
def checkAny (customSection : Option SectionSpec) : Except String Unit := do
  let some customSection := customSection | return ()
  if (checkELF customSection).isOk || (checkApple customSection).isOk then return ()
  -- This choice affects only the diagnostic when neither grammar accepts.
  if customSection.name.startsWith "." ||
      (!(customSection.name.contains ',') && customSection.flags.isNone) then checkELF customSection
  else checkApple customSection

/-- Never infer the object format from a name prefix. Preserve both the target
    mismatch diagnostic and its concrete grammar reason for unsupported forms. -/
def checkTarget (darwin : Bool) (customSection : Option SectionSpec) : Except String Unit := do
  let some customSection := customSection | return ()
  let selected := if darwin then checkApple customSection else checkELF customSection
  match selected with
  | .ok () => return ()
  | .error error =>
    let other := if darwin then checkELF customSection else checkApple customSection
    if other.isOk then
      throw s!"custom section syntax does not match the selected object format: {error}"
    throw error

/-- Bounded ELF custom TLS storage: explicit allocatable, writable TLS flags, optionally retained.
    This is data-context validation; ordinary sections still reject T. -/
def checkTLS (customSection : SectionSpec) : Except String Unit := do
  checkELF { customSection with flags := none }
  let some flags := customSection.flags
    | throw "custom TLS section requires explicit awT flags (optional R)"
  if !flags.toList.all (fun c => c == 'a' || c == 'w' || c == 'T' || c == 'R') ||
      !flags.contains 'a' || !flags.contains 'w' || !flags.contains 'T' then
    throw "custom TLS section requires allocatable writable TLS flags (awT, optional R)"

def checkDataAny (threadLocal : Bool) (customSection : Option SectionSpec) : Except String Unit := do
  if threadLocal then
    if let some spec := customSection then return ← checkTLS spec
  checkAny customSection

def checkDataTarget (darwin threadLocal : Bool) (customSection : Option SectionSpec) : Except String Unit := do
  if threadLocal then
    if let some spec := customSection then
      if darwin then throw "Apple thread data cannot have a custom section"
      return ← checkTLS spec
  checkTarget darwin customSection

end LeanCompilerBackend.Section

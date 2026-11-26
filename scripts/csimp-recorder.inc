-- The journal is process-wide so scope exit and compiler snapshots cannot
-- roll back a recorded lookup. The driver writes it after emitting the code.
private builtin_initialize recorded :
    Std.Mutex (Std.HashSet (Name × Name × Name)) ← Std.Mutex.new {}

private def nameParts : Name → List Json
  | .anonymous => []
  | .str parent part => nameParts parent ++ [.str part]
  | .num parent part => nameParts parent ++ [toJson part]

private def recordRewrite (ent : Entry) : BaseIO Unit :=
  recorded.atomically <| modify (·.insert (ent.fromDeclName, ent.toDeclName, ent.thmName))

@[export lean_lcb_csimp_journal]
private def rewriteJournal (_ : Unit) : BaseIO String := recorded.atomically do
  let entries := (← get).toArray.map fun (source, target, theoremName) =>
    (toJson [nameParts source, nameParts target, nameParts theoremName]).compress
  return String.join (entries.qsort (· < ·) |>.toList.map (· ++ "\n"))

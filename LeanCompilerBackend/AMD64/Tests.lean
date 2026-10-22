import LeanCompilerBackend.AMD64
import LeanCompilerBackend.Parser

namespace LeanCompilerBackend.AMD64.Tests

def run : IO Unit := do
  let bank := #["rbx","r12","r13","r14","r15","r8","r9"]
  let header := "type :big = {l,l,l}\ntype :pair = {l,l}\ntype :mixed = {l,d}\n"
  let cases := [
    ("l", "l %p,l %a,l %b,l %c", "@s\n ret %p", true),
    ("l", "l %p,l %a,l %b,l %c,l %d", "@s\n ret %p", false),
    ("l", "l %p,l %a,l %b,l %c,l %d,l %e", "@s\n ret %p", false),
    (":big", "l %p,l %a,l %b", "@s\n ret %p", true),
    (":big", "l %p,l %a,l %b,l %c", "@s\n ret %p", false),
    ("l", ":pair %p,l %a,l %b,l %c", "@s\n ret %a", false),
    ("l", ":mixed %p,l %a,l %b,l %c", "@s\n ret %a", true),
    ("l", "d %f0,d %f1,d %f2,d %f3,d %f4,d %f5,d %f6,d %f7,:mixed %m,l %p,l %a,l %b,l %c", "@s\n ret %p", true),
    ("l", "env %env,l %p,l %a,l %b,l %c", "@s\n ret %env", true),
    ("l", "l %p,l %a,l %b,l %c,...", "@s\n ret %p", true),
    ("l", "l %p", "@s\n call $other()\n ret %p", false),
    ("l", "l %p", "@s\n %r =l call %p()\n ret %r", false),
    ("l", "l %p", "@s\n storel thread $slot,%p\n ret %p", false),
    ("l", "l %p", "@s\n ret thread $slot", false),
    ("l", "l %p", "@s\n jmp @j\n@j\n %r =l phi @s thread $slot\n ret %r", false),
    ("l", "l %p", "@s\n jnz thread $slot,@a,@b\n@a\n ret %p\n@b\n ret %p", false),
    ("l", "l %p", "@s\n ret %p\n@dead\n call $other()\n ret %p", false)]
  for (result,params,body,expected) in cases do
    let m ← match Parser.parseModule (header ++ "function " ++ result ++ " $bank(" ++ params ++ ") {\n" ++ body ++ "\n}\n") with
      | .ok m => pure m | .error e => throw (IO.userError e)
    let types ← match AMD64ABI.classify m.types with
      | .ok t => pure t | .error e => throw (IO.userError e)
    let f := m.functions[0]!
    unless (checkPhysicalBank f types bank).isOk == expected do
      throw (IO.userError s!"AMD64 physical-bank eligibility differs for {params}: {body}")
    for bad in [#["rbx","r12","r13","r14","r15","rax","r9"],#["rbx","r12","r13","r14","r15","r8","r8"]] do
      unless !(checkPhysicalBank f types bad).isOk do throw (IO.userError "AMD64 bad physical bank accepted")
  IO.println "AMD64 leaf banks: ABI GP boundaries, hidden result, aggregate rollback, env/varargs and call/TLS/scratch controls passed"

end LeanCompilerBackend.AMD64.Tests

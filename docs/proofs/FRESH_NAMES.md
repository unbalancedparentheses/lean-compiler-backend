# Generated-name collision avoidance

`LeanCompilerBackend/Verified/FreshNameProofs.lean` proves properties of the
actual `SSA.freshNamePrefix` implementation shared by SSA construction, scalar
memory promotion, and global-symbol materialization. Compiler implementation
files are unchanged.

For arbitrary `base`, an array of existing identifiers `names`, and any member
`name` of that array:

- `freshNamePrefix_append_ne`: appending any string suffix to the computed
  prefix cannot produce `name`.
- `freshNamePrefix_not_prefix`: `name` does not start with that prefix.
- `freshNamePrefix_counter_ne`: the decimal-counter names used by the passes
  cannot equal `name`, for any natural-number counter.

The proof first rewrites the executable `Id`/`for` scan into an equal fold. The
fold bounds the leading underscore depth of every existing identifier that
starts with `base`. An identifier equal to the computed prefix plus a suffix
would need more leading underscores than this bound permits, a contradiction.
The statement covers empty and Unicode strings, arbitrary underscore runs,
duplicate input names, and arbitrary suffixes without special assumptions.

This is **not** a proof that the callers collect every relevant identifier, that
different generated counters are distinct, or that SSA construction, memory
promotion, symbol materialization, or emitted machine code preserves program
behavior. Those require separate statements and proofs. The theorem guarantees
collision avoidance relative to the exact array passed to the helper.

The normal proof audit checks all three declarations. Their dependencies are
Lean's standard `propext`, `Classical.choice`, and `Quot.sound`; there are no
additional axioms, `sorry`, or native-evaluation assumptions.

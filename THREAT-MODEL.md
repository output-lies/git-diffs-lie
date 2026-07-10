# Threat model

A code reviewer decides whether a change is safe by reading its **diff**. The
diff is rendered by tooling (git's pager, a GUI difftool, a terminal). An
attacker who controls the change can target that rendering so that what the
reviewer SEES differs from what git will APPLY.

The safe git review tools are external diff drivers (`diff.external`): git
invokes them per changed file. They defend the reviewer along these axes:

- **Content bytes.** Bidi overrides, homoglyphs, zero-width and invisible
  characters, undecodable bytes, terminal control sequences, over-long lines and
  NUL bytes are neutralized (rendered inert) instead of reaching the terminal
  raw. SGR color sequences are deliberately preserved so legitimate colored
  diffs still render.
- **Path names.** The same classes hidden in a FILENAME are surfaced, not
  printed raw (a filename can carry a bidi override, a tab, or a newline that
  forges diff output).
- **Metadata, not content.** A change can be invisible to a content diff: a
  mode-only change (executable bit), a file-to-symlink type change, a symlink
  retarget, or a submodule (gitlink) pointer bump. These are shown explicitly.
- **Structural traps.** A `.gitattributes` added in the same change can mark
  another changed file `-diff`, hiding it from a naive `git diff`. The tools
  fail closed on a `.gitattributes` change (override with
  `GIT_REVIEW_ALLOW_GITATTRIBUTES=1`).
- **Ref names.** git blocks control bytes in ref names but allows bidi,
  homoglyph and zero-width characters, so a fetched branch name can visually
  spoof another. Scan ref names with `check-ref-names-for-unicode`.

Design stance: **fail closed**. When the tool cannot safely render or decide, it
stops rather than showing the reviewer something misleading.

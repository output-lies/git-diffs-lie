# Catalog

Every branch, its payload, and the surprise `git diff master..<branch>` reveals.
Bytes are given as hex so this document stays plain ASCII.

## Content

- **content/bidi-trojan-source** -- U+202E (`e2 80 ae`) in `src/hello.c`. Naive:
  the terminal reorders the line so the visible code differs from the bytes
  (Trojan Source, CVE-2021-42574). Safe: the override is neutralized to `_`.
- **content/homoglyph-identifier** -- Cyrillic `a` U+0430 (`d0 b0`) in an
  identifier. Naive: the call reads as `validate` but the `a` is Cyrillic, so it
  targets a different identifier. Safe: the non-ASCII byte is neutralized.
- **content/zero-width** -- U+200B (`e2 80 8b`) splits a token. Naive: invisible.
  Safe: neutralized.
- **content/unicode-whitespace** -- U+00A0 no-break space (`c2 a0`) where an
  ASCII space is expected. This is the "space as Unicode" case; it is surfaced,
  never treated as a tool failure.
- **content/invalid-utf8** -- a raw `ff` byte. Naive: mojibake or a silent
  replacement char. Safe: fail closed on undecodable input.
- **content/overlong-line** -- one 6000-character line. Naive: truncation or a
  stalled pager. Safe: flagged.
- **content/nul-byte** -- an embedded `00`. Naive: the file looks empty or
  truncated. Safe: treated as binary; content suppressed, a note shown.
- **content/ansi-escape** -- a non-SGR escape (`1b [1A`, `1b [2K`) rewrites the
  previous line. Naive: the terminal shows forged output. Safe: neutralized.
  (SGR color codes are intentionally NOT neutralized.)
- **content/lone-cr** -- a bare carriage return (`0d`) overwrites the visible
  line. Naive: only the text after the CR is shown. Safe: neutralized.

## Paths

- **path/bidi-filename** -- U+202E in a filename; its real `.txt` tail renders
  flipped, so the name looks like it ends in an image extension. Naive: the name
  is misread. Safe: surfaced.
- **path/tab-in-filename** -- a tab in a filename can forge columns in status or
  diff output. Safe: surfaced.
- **path/newline-in-filename** -- a newline in a filename can forge whole diff
  lines. Safe: surfaced.
- **path/gitattributes-hide-diff** -- `secret.txt` is changed AND a
  `.gitattributes` marks it `-diff`. Naive: `git diff` shows no change to
  `secret.txt`. Safe: fail closed on the `.gitattributes` change.
- **path/gitattributes-nonascii-dir** -- the same trap (a changed `data.txt`
  hidden by `* -diff`) inside a non-ASCII-named directory. git quotes the path
  in `--name-only` (core.quotePath), so a text match would miss it; the gate
  reads raw `-z` names and still fails closed.

## Mode / type

- **type/mode-exec** -- the executable bit is set with no content change. Naive:
  a content diff shows nothing. Safe: the mode change is reported.
- **type/file-to-symlink** -- a regular file becomes a symlink. Safe: the type
  change and target are shown.
- **type/symlink-retarget** -- a symlink is repointed at `/nonexistent/
  DEMO-CREDENTIALS`. Naive: the retarget can be hidden. Safe: old and new
  targets are shown.
- **type/dangling-symlink** -- a new symlink points at a nonexistent target.
  Naive: viewers that stat the target render it empty. Safe: the link text is
  shown.
- **type/submodule-bump** -- the `vendor/sub` gitlink moves to a different,
  unfetched commit. Naive: invisible to a content diff. Safe: the pointer change
  is shown, and (because the submodule is not initialized) the tool fails closed
  rather than pretend it reviewed the inner change.
- **type/gitlink-mimic** -- a regular file whose content is
  `Subproject commit <40 hex>` (and no trailing newline). Safe: flagged as a
  gitlink look-alike rather than trusted.

## Ref names

- The two intentionally non-clean branches carry a bidi override and a homoglyph
  of `master` in the branch NAME. Diff content is trivial; the surprise is the
  name, surfaced by `check-ref-names-for-unicode`.

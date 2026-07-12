#!/bin/bash

## Copyright (C) 2025 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>

## AI-Assisted

## build-corpus.sh -- (re)generate the git-diffs-lie corpus.
##
## Each branch differs from a clean 'master' by exactly ONE safe, educational
## surprise that a naive diff/pager hides or misrenders but the safe git review
## tools (git-meld, git-diff-review, ...) surface. master carries only
## documentation and clean baseline files, so 'git diff master..<branch>' is
## always one surprise.
##
## All payloads are safe: RFC2606 example.* hosts, obviously-fake symlink
## targets, harmless terminal escapes, benign "hidden" text, and published
## Trojan-Source-style Unicode. Nothing here is executed by reviewing it.
##
## Usage: build-corpus.sh <target-directory>
##   The target directory is created fresh (removed first if it exists).

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace
shopt -s inherit_errexit
shopt -s shift_verbose

target="${1:-}"
if [ -z "${target}" ]; then
   printf 'Usage: %s <target-directory>\n' "${0##*/}" >&2
   exit 1
fi

## This generator, copied verbatim into the corpus so the repo can rebuild
## itself.
self_source="$(readlink --canonicalize -- "${0}")"

## Pin git to pristine defaults so payload bytes survive regeneration (a global
## core.autocrlf would mangle the CR/CRLF fixtures) and no session-specific
## ambient identity leaks in. Identity: the AI author (never the user's personal
## identity).
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME='claude'
export GIT_AUTHOR_EMAIL='noreply@anthropic.com'
export GIT_COMMITTER_NAME="${GIT_AUTHOR_NAME}"
export GIT_COMMITTER_EMAIL="${GIT_AUTHOR_EMAIL}"

## Commit timestamps use the current clock (the corpus is regenerated rarely;
## fixed timestamps just made every commit read as months old on the forge).

## ---------------------------------------------------------------------------
## Byte payloads (emitted via printf so this generator stays pure ASCII).
## ---------------------------------------------------------------------------
BIDI_RLO="$(printf '\xe2\x80\xae')"          ## U+202E RIGHT-TO-LEFT OVERRIDE
BIDI_PDF="$(printf '\xe2\x80\xac')"          ## U+202C POP DIRECTIONAL FORMATTING
HOMOGLYPH_A="$(printf '\xd0\xb0')"           ## U+0430 CYRILLIC SMALL LETTER A
ZERO_WIDTH="$(printf '\xe2\x80\x8b')"        ## U+200B ZERO WIDTH SPACE
NBSP="$(printf '\xc2\xa0')"                  ## U+00A0 NO-BREAK SPACE
ESC="$(printf '\x1b')"                       ## ESC (ANSI CSI introducer)
CR="$(printf '\r')"                          ## carriage return

## Ref-name payloads (the branch NAME is the attack); defined here so the
## manifest can reference them.
refname_bidi="$(printf 'release%sgpj' "${BIDI_RLO}")"
refname_homoglyph="$(printf 'm%sster' "${HOMOGLYPH_A}")"

## A non-ASCII directory name (UTF-8 'mor' with an o-umlaut). git quotes such a
## path in 'git diff --name-only' output (core.quotePath).
nonascii_dir="$(printf 'm\xc3\xb6r')"

## ---------------------------------------------------------------------------
## Documentation writers (run from inside the target working tree).
## ---------------------------------------------------------------------------
write_readme() {
   cat > README.md <<'EOF'
# git-diffs-lie

A curated corpus of adversarial and edge-case git diffs. **Each branch differs
from `master` by exactly one safe, educational "surprise"** that a naive diff or
pager hides or misrenders, but the safe git review tools (`git-meld`,
`git-diff-review`, `git-review-difftool`, `git-review-mergetool`) surface.

**Live, illustrated walk-through (what you see vs what's really happening):**
<https://output-lies.github.io/git-diffs-lie/>

> Scope note: this repo is the corpus of adversarial diffs the review tools are
> meant to **defend against**. It is not a list of vulnerabilities *in* those
> tools.

## How to use it

`master` is a clean baseline plus documentation only, so every

```
git diff master..<branch>
```

is exactly one surprise. Compare a naive viewer with a safe one:

```
git --no-pager diff master..content/bidi-trojan-source      # naive: bytes reach your terminal
git -c diff.external=git-diff-review diff master..content/bidi-trojan-source   # safe: neutralized
```

or drive the tools directly (`git-meld master content/bidi-trojan-source`).

## Everything is safe

All payloads are benign: RFC2606 `example.*` hosts, obviously-fake symlink
targets (`/nonexistent/DEMO-*`), harmless terminal escapes, benign "hidden"
text, and published Trojan-Source-style Unicode. Reviewing a branch executes
nothing.

## The safe tools

The external diff drivers that neutralize, surface, and fail closed on all of
this live in Kicksecure's developer-meta-files:
<https://github.com/Kicksecure/developer-meta-files/tree/master/usr/bin>
(`git-meld`, `git-kdiff3`, `git-diff-review`, `git-review-difftool`,
`git-review-mergetool`).

## Layout

- `CATALOG.md` -- every branch: payload (as hex), what a naive viewer does, what
  the safe tool does, references.
- `THREAT-MODEL.md` -- what a diff reviewer is defending against.
- `manifest.tsv` -- machine-readable case list that drives the test suite.
- `tools/build-corpus.sh` -- the generator; regenerates this entire repo.
- `tools/verify-corpus.sh` -- checks the corpus is well-formed.

## Regenerate

```
tools/build-corpus.sh /tmp/corpus && cd /tmp/corpus
```

## Branch-name payloads

Branch names are clean and descriptive **except** the two where the branch NAME
itself is the payload (a bidi override and a homoglyph of `master`). Those
demonstrate that `git fetch` prints new ref names verbatim.
EOF
}

write_threat_model() {
   cat > THREAT-MODEL.md <<'EOF'
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
EOF
}

write_catalog() {
   cat > CATALOG.md <<'EOF'
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
EOF
}

write_manifest() {
   ## Tab-separated: branch <TAB> class <TAB> assert <TAB> arg <TAB> summary.
   ## assert vocabulary consumed by the test runner:
   ##   neutralized  arg=<hex>  -- raw byte sequence must be ABSENT from stdout
   ##   failclosed   arg=-      -- the review tool must exit non-zero
   ##   shows        arg=<text> -- text must appear in the tool's output
   ##   refname      arg=<hex>  -- branch-NAME case; scanned by unicode-show
   {
      printf '# branch\tclass\tassert\targ\tsummary\n'
      printf 'content/bidi-trojan-source\tcontent\tneutralized\te280ae\tbidi override reorders the visible line\n'
      printf 'content/homoglyph-identifier\tcontent\tneutralized\td0b0\tCyrillic a masquerades as Latin a\n'
      printf 'content/zero-width\tcontent\tneutralized\te2808b\tzero-width space splits a token\n'
      printf 'content/unicode-whitespace\tcontent\tneutralized\tc2a0\tno-break space for an ASCII space\n'
      printf 'content/invalid-utf8\tcontent\tfailclosed\t-\tundecodable UTF-8 byte\n'
      printf 'content/overlong-line\tcontent\tshows\tchar line\tsingle 6000-character line\n'
      printf 'content/nul-byte\tcontent\tshows\tNUL byte\tembedded NUL, treated binary\n'
      printf 'content/ansi-escape\tcontent\tneutralized\t1b5b324b\tnon-SGR escape rewrites the line\n'
      printf 'content/lone-cr\tcontent\tneutralized\t0d\tlone CR overwrites the line\n'
      printf 'path/bidi-filename\tpath\tshows\tsuspicious\tbidi override inside a filename\n'
      printf 'path/tab-in-filename\tpath\tshows\tforge diff-output\ttab inside a filename\n'
      printf 'path/newline-in-filename\tpath\tshows\tforge diff-output\tnewline inside a filename\n'
      printf 'path/gitattributes-hide-diff\tpath\tfailclosed\t-\t.gitattributes hides a real change\n'
      printf 'path/gitattributes-nonascii-dir\tpath\tfailclosed\t-\t.gitattributes in a non-ASCII dir\n'
      printf 'type/mode-exec\ttype\tshows\tmode\texecutable bit set, no content change\n'
      printf 'type/file-to-symlink\ttype\tshows\tsymlink\tfile becomes a symlink\n'
      printf 'type/symlink-retarget\ttype\tshows\tDEMO-CREDENTIALS\tsymlink retargeted\n'
      printf 'type/dangling-symlink\ttype\tshows\tDEMO-MISSING\tdangling symlink\n'
      printf 'type/submodule-bump\ttype\tshows\tSubmodule\tgitlink pointer bumped\n'
      printf 'type/gitlink-mimic\ttype\tshows\tmimics\tfile mimics a gitlink line\n'
      printf '%s\trefname\trefname\te280ae\tbidi override in the branch name\n' "${refname_bidi}"
      printf '%s\trefname\trefname\td0b0\thomoglyph branch name spoofing master\n' "${refname_homoglyph}"
   } > manifest.tsv
}

write_verifier() {
   cat > tools/verify-corpus.sh <<'EOF'
#!/bin/bash

## Copyright (C) 2025 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>

## AI-Assisted

## Check the corpus is well-formed: every non-master branch is listed in
## manifest.tsv (and vice-versa) and has a non-empty diff against master.
set -o errexit
set -o nounset
set -o pipefail
set -o errtrace
shopt -s inherit_errexit
shopt -s shift_verbose

cd -- "$(dirname -- "$(readlink --canonicalize -- "${0}")")/.."

fail=0
while IFS="$(printf '\t')" read -r branch _class _assert _arg _summary; do
   case "${branch}" in ''|'#'*) continue ;; esac
   if ! git rev-parse --verify --quiet "refs/heads/${branch}" >/dev/null; then
      printf 'MISSING branch for manifest row: %s\n' "${branch}" >&2
      fail=1
      continue
   fi
   if git diff --quiet master.."${branch}"; then
      printf 'EMPTY diff master..%s\n' "${branch}" >&2
      fail=1
   fi
done < manifest.tsv

## Every branch except master must appear in the manifest.
while read -r branch; do
   if [ "${branch}" = master ]; then
      continue
   fi
   ## Exact match against the manifest's first column (a bare substring grep
   ## would treat a branch name that is a substring of any row as present).
   if ! cut -f1 manifest.tsv | grep --quiet --line-regexp --fixed-strings -- "${branch}"; then
      printf 'branch not in manifest: %s\n' "${branch}" >&2
      fail=1
   fi
done < <(git for-each-ref --format='%(refname:short)' refs/heads/)

if [ "${fail}" = 0 ]; then
   printf 'verify-corpus: OK\n'
fi
exit "${fail}"
EOF
   chmod +x -- tools/verify-corpus.sh
}

## ---------------------------------------------------------------------------
## Fresh repository + clean master.
## ---------------------------------------------------------------------------
safe-rm --recursive --force -- "${target}"
mkdir --parents -- "${target}"
cd -- "${target}"
git init --quiet --initial-branch=master

mkdir --parents -- src data docs tools vendor

cat > src/hello.c <<'EOF'
#include <stdio.h>

/* Grant access only to an administrator. */
int is_authorized(const char *role) {
   if (validate(role) && role_is_admin(role)) {
      return 1;
   }
   return 0;
}

int main(void) {
   printf("hello, world\n");
   return 0;
}
EOF

cat > src/build.sh <<'EOF'
#!/bin/bash
## A clean, non-executable baseline shell file.
set -o errexit -o nounset -o pipefail
gcc -Wall -o hello src/hello.c
EOF

cat > data/config.env <<'EOF'
## A clean baseline configuration file.
UPDATE_HOST=updates.example.com
UPDATE_PORT=443
RETRY_LIMIT=3
EOF

printf 'This project is a public example.\n' > notes.txt
printf 'This value is public.\n' > secret.txt
printf 'A regular file that a branch turns into a symlink.\n' > swap.txt
ln --symbolic -- notes.txt link-notes

## A tracked file inside a non-ASCII-named directory; a branch changes it AND
## hides the change with a '* -diff' .gitattributes there (quotePath case).
mkdir --parents -- "${nonascii_dir}"
printf 'This value in a non-ASCII directory is public.\n' > "${nonascii_dir}/data.txt"

## A legitimate submodule pointer (gitlink) on master; a branch bumps it. No
## real submodule checkout is needed to demonstrate the pointer-level surprise.
cat > .gitmodules <<'EOF'
[submodule "vendor/sub"]
	path = vendor/sub
	url = https://vcs.example.com/vendor/sub.git
EOF

cp -- "${self_source}" tools/build-corpus.sh
chmod +x -- tools/build-corpus.sh

## Documentation (written below via functions to keep this section readable).
write_readme
write_catalog
write_threat_model
write_manifest
write_verifier

git add --all -- .
git update-index --add --cacheinfo \
   160000,1111111111111111111111111111111111111111,vendor/sub
git commit --quiet --message 'master: clean baseline, docs, and corpus generator'

## new_case <branch-name> -- start a fresh branch off clean master.
new_case() {
   git checkout --quiet master
   git checkout --quiet -b "${1}"
}

## finish_case <commit-subject> [path...] -- stage and commit the surprise.
finish_case() {
   local subject="${1}"
   shift
   if [ "${#}" -gt 0 ]; then
      git add --all -- "${@}"
   else
      git add --all -- .
   fi
   git commit --quiet --message "${subject}"
}

## =========================================================================
## Content surprises (bytes inside a file's content).
## =========================================================================

## content/bidi-trojan-source -- U+202E reorders the visual line vs the logical
## bytes (Trojan Source). Here it visually swaps the returned constants.
new_case content/bidi-trojan-source
printf '#include <stdio.h>\n\nconst char *access_level(int admin) {\n   /* return %snimda%s */ return admin ? "user" : "admin";\n}\n' \
   "${BIDI_RLO}" "${BIDI_PDF}" > src/hello.c
finish_case 'content: bidi override reorders the visible line (Trojan Source)' src/hello.c

## content/homoglyph-identifier -- a Cyrillic 'a' masquerades as Latin 'a', so
## the call targets a different identifier than it appears to.
new_case content/homoglyph-identifier
printf '#include <stdio.h>\n\nint main(void) {\n   return v%slidate("role");\n}\n' \
   "${HOMOGLYPH_A}" > src/hello.c
finish_case 'content: homoglyph identifier (Cyrillic a for Latin a)' src/hello.c

## content/zero-width -- a zero-width space splits a token invisibly.
new_case content/zero-width
printf 'ADMIN%sTOKEN=granted\n' "${ZERO_WIDTH}" > data/config.env
finish_case 'content: zero-width space hidden inside a token' data/config.env

## content/unicode-whitespace -- a NO-BREAK SPACE stands in for an ASCII space.
## The user-reported "space as Unicode" case; must NOT be treated as an stcat
## failure, only surfaced.
new_case content/unicode-whitespace
printf 'RETRY_LIMIT%s=%s0\n' "${NBSP}" "${NBSP}" > data/config.env
finish_case 'content: no-break space where an ASCII space is expected' data/config.env

## content/invalid-utf8 -- a raw non-UTF-8 byte (undecodable); the tools fail
## closed rather than guess.
new_case content/invalid-utf8
printf 'checksum=\xff\xfe not valid utf-8\n' > data/config.env
finish_case 'content: invalid (undecodable) UTF-8 byte' data/config.env

## content/overlong-line -- one enormous single line; naive pagers truncate or
## stall.
new_case content/overlong-line
{ printf 'payload='; printf 'A%.0s' {1..6000}; printf '\n'; } > data/config.env
finish_case 'content: single 6000-character line' data/config.env

## content/nul-byte -- a NUL byte makes git treat the file as binary (content
## suppressed; only a --stat/NOTE is shown).
new_case content/nul-byte
printf 'before\x00after\n' > data/config.env
finish_case 'content: embedded NUL byte (file treated as binary)' data/config.env

## content/ansi-escape -- a cursor-movement + erase-line sequence (NOT a color
## code) rewrites the previous line so the terminal shows "PASS" over "FAIL".
## Non-SGR escapes are neutralized; SGR color codes are deliberately preserved.
new_case content/ansi-escape
printf 'STATUS=FAIL%s[1A%s[2KSTATUS=PASS\n' \
   "${ESC}" "${ESC}" > data/config.env
finish_case 'content: non-SGR ANSI escape rewrites the visible line' data/config.env

## content/lone-cr -- a bare carriage return rewrites the visible line so the
## terminal shows only the text after it.
new_case content/lone-cr
printf 'DELETE_EVERYTHING=yes%sDELETE_EVERYTHING=no\n' "${CR}" > data/config.env
finish_case 'content: lone carriage return overwrites the visible line' data/config.env

## =========================================================================
## Path / filename surprises.
## =========================================================================

## path/bidi-filename -- a bidi override in the NAME flips the real ".txt" tail
## so it looks like an image extension.
new_case path/bidi-filename
bidi_name="$(printf 'report%sgpj.txt' "${BIDI_RLO}")"
printf 'attachment\n' > "${bidi_name}"
finish_case 'path: bidi override inside a filename'

## path/tab-in-filename -- a tab in the name can forge columns in diff/status
## output.
new_case path/tab-in-filename
tab_name="$(printf 'notes\tevil.txt')"
printf 'tabbed name\n' > "${tab_name}"
finish_case 'path: tab character inside a filename'

## path/newline-in-filename -- a newline in the name can forge whole diff lines.
new_case path/newline-in-filename
nl_name="$(printf 'notes\ninjected.txt')"
printf 'newlined name\n' > "${nl_name}"
finish_case 'path: newline character inside a filename'

## path/gitattributes-hide-diff -- a .gitattributes marks a genuinely changed
## file '-diff', so a naive 'git diff' shows nothing for it. The review tools
## fail closed on the .gitattributes change itself.
new_case path/gitattributes-hide-diff
printf 'This value is now SENSITIVE and was changed.\n' > secret.txt
printf 'secret.txt -diff\n' > .gitattributes
finish_case 'path: .gitattributes hides a real change (-diff)'

## path/gitattributes-nonascii-dir -- the same trap, but the .gitattributes
## lives in a non-ASCII-named directory. git quotes such paths in
## 'git diff --name-only' (core.quotePath), so a text match misses it; the gate
## reads raw -z names and still fails closed.
new_case path/gitattributes-nonascii-dir
printf 'This value in a non-ASCII directory is now SENSITIVE and changed.\n' \
   > "${nonascii_dir}/data.txt"
printf '* -diff\n' > "${nonascii_dir}/.gitattributes"
finish_case 'path: .gitattributes hides a real change in a non-ASCII dir (quotePath)'

## =========================================================================
## Mode / type surprises.
## =========================================================================

## type/mode-exec -- the executable bit is set with no content change, so a
## content-only diff shows nothing.
new_case type/mode-exec
chmod +x -- src/build.sh
finish_case 'type: executable bit set, no content change' src/build.sh

## type/file-to-symlink -- a regular file becomes a symlink.
new_case type/file-to-symlink
safe-rm --force -- swap.txt
ln --symbolic -- /nonexistent/DEMO-TARGET swap.txt
finish_case 'type: regular file replaced by a symlink'

## type/symlink-retarget -- an existing symlink is quietly repointed at a
## sensitive-looking (fake) target.
new_case type/symlink-retarget
ln --symbolic --force -- /nonexistent/DEMO-CREDENTIALS link-notes
finish_case 'type: symlink retargeted to a sensitive-looking path'

## type/dangling-symlink -- a new symlink points at a nonexistent target; naive
## viewers that stat the target render it empty.
new_case type/dangling-symlink
ln --symbolic -- ../nowhere/DEMO-MISSING link-dangling
finish_case 'type: dangling symlink (nonexistent target)'

## type/submodule-bump -- the gitlink pointer moves to a different (unfetched)
## commit; the change is invisible to a content diff.
new_case type/submodule-bump
git update-index --cacheinfo \
   160000,2222222222222222222222222222222222222222,vendor/sub
git commit --quiet --message 'type: submodule gitlink bumped to an unfetched commit'

## type/gitlink-mimic -- a regular file whose CONTENT mimics a gitlink line,
## spoofing the "Subproject commit" display without being a real submodule.
new_case type/gitlink-mimic
printf 'Subproject commit 3333333333333333333333333333333333333333' \
   > fake-sub
finish_case 'type: regular file mimics a gitlink line (no trailing newline)'

## =========================================================================
## Ref-name surprises -- here the BRANCH NAME itself is the payload, so these
## names are intentionally NOT clean (every other branch name is descriptive).
## =========================================================================

## A bidi override inside the branch name; git prints it verbatim after a fetch.
new_case "${refname_bidi}"
printf 'ordinary content; the surprise is this branch NAME.\n' > notes.txt
finish_case 'refname: bidi override inside the branch name' notes.txt

## A homoglyph branch name that sits next to 'master' in the branch list.
new_case "${refname_homoglyph}"
printf 'ordinary content; the surprise is this branch NAME.\n' > notes.txt
finish_case 'refname: homoglyph branch name spoofing master' notes.txt

git checkout --quiet master
printf 'Built corpus at %s\n' "${target}"
printf 'Branches:\n'
git for-each-ref --format='  %(refname:short)' refs/heads/

# git-diffs-lie

A curated corpus of adversarial and edge-case git diffs. **Each branch differs
from `master` by exactly one safe, educational "surprise"** that a naive diff or
pager hides or misrenders, but the safe git review tools (`git-meld`,
`git-diff-review`, `git-review-difftool`, `git-review-mergetool`) surface.

**Live, illustrated walk-through (what you see vs what's really happening):**
<https://org-ai-assisted.github.io/git-diffs-lie/>

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

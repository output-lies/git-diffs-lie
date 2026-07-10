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

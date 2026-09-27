#!/usr/bin/env bash
# Verify parse trees (no ERROR) and that highlight queries produce the
# captures we care about for the required snippets.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v tree-sitter >/dev/null 2>&1; then
  echo "tree-sitter CLI is required for this check" >&2
  exit 1
fi

fail=0
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

check_parse() {
  local name="$1" src="$2"
  local file="$tmpdir/$name.gohtml"
  printf '%s' "$src" >"$file"
  local out
  out="$(tree-sitter parse "$file" 2>&1 || true)"
  if grep -q 'ERROR' <<<"$out"; then
    echo "FAIL parse $name"
    echo "$out"
    fail=1
  else
    echo "OK   parse $name"
  fi
}

check_captures() {
  local name="$1" src="$2"
  shift 2
  local file="$tmpdir/$name.gohtml"
  printf '%s' "$src" >"$file"
  local out
  out="$(tree-sitter query queries/gohtml/highlights.scm "$file" 2>/dev/null || true)"
  local missing=0
  local token
  for token in "$@"; do
    if ! grep -Fq "$token" <<<"$out"; then
      echo "FAIL highlight $name: missing capture token: $token"
      missing=1
      fail=1
    fi
  done
  if [[ $missing -eq 0 ]]; then
    echo "OK   highlight $name"
  fi
}

s1='<h1>{{.Title}}</h1>'
s2='<div class="{{.Class}}">{{.Name}}</div>'
s3='{{if .User}}<p>{{.User.Name}}</p>{{else}}<p>Guest</p>{{end}}'
s4='{{range .Items}}<li>{{.}}</li>{{end}}'
s5='{{- /* note */ -}}'
s6='<!-- keep --><script type="text/javascript">var x=1;</script><style type="text/css">h1{color:red}</style><p>ok</p>'

check_parse title "$s1"
check_parse attr "$s2"
check_parse ifelse "$s3"
check_parse range "$s4"
check_parse comment "$s5"
check_parse htmlmisc "$s6"

check_captures title "$s1" 'tag, start:' 'variable.member' '.Title' 'punctuation.special'
check_captures attr "$s2" 'tag.attribute' 'class' '.Class' '.Name'
check_captures ifelse "$s3" 'keyword.conditional' 'if' 'else' 'end' '.User'
check_captures range "$s4" 'keyword.repeat' 'range' 'variable.builtin'
check_captures comment "$s5" 'comment' 'punctuation.special'
check_captures htmlmisc "$s6" 'comment' 'tag' 'script' 'style'

if [[ $fail -ne 0 ]]; then
  echo "highlight/parse checks failed"
  exit 1
fi

echo "All parse + highlight checks passed"

#!/bin/sh
# new-post.sh - post na kanal koordynacji z REALNYM czasem UTC (date -u) - koniec recznego wpisywania ts.
# Tresc posta = stdin. ts + nazwa pliku brane z zegara, nigdy zgadywane.
#
# Uzycie:
#   printf '%s\n' "tresc" | sh tools/new-post.sh <Autor> [do-<rola|all>__<temat>] [reply_to_id]
#   sh tools/new-post.sh AgentA do-all__status < tresc.md
#
# Nazwa pliku: <ISO-myslniki>__<autor>[__do-<adresat>__<temat>].md - adres w nazwie pozwala
# watcherowi (P1 relevance-gate) budzic tylko adresata. Wypisuje sciezke utworzonego pliku;
# commit+push robisz osobno (git add <plik> && git commit && git push <remote> master).
set -eu
author="${1:?Uzycie: new-post.sh <Autor> [do-<rola|all>__<temat>] [reply_to_id] ; tresc na stdin}"
slug="${2:-}"
reply="${3:-}"
case "$author" in
  *[!A-Za-z0-9_-]*|"") echo "BLAD: autor '$author' musi pasowac do [A-Za-z0-9_-]+" >&2; exit 1 ;;
esac
if [ -n "$slug" ]; then
  case "$slug" in
    do-*__*) case "$slug" in *[!A-Za-z0-9_-]*) echo "BLAD: slug '$slug' zawiera niedozwolone znaki (dozwolone [A-Za-z0-9_-])" >&2; exit 1 ;; esac ;;
    *) echo "BLAD: slug musi miec forme do-<rola|all>__<temat> (dostal: '$slug')" >&2; exit 1 ;;
  esac
  role="${slug#do-}"; role="${role%%__*}"
  topic="${slug#do-*__}"
  if [ -z "$role" ] || [ -z "$topic" ]; then
    echo "BLAD: rola i temat w slugu nie moga byc puste (do-<rola|all>__<temat>, dostal: '$slug')" >&2; exit 1
  fi
fi
ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
fts="$(date -u '+%Y-%m-%dT%H-%M-%SZ')"
dir="${FORUM_DIR:-$(CDPATH= cd "$(dirname "$0")/.." && pwd)}/posts"
mkdir -p "$dir"
f="${dir}/${fts}__${author}${slug:+__${slug}}.md"
{
  echo '---'
  echo "author: ${author}"
  echo "ts: ${ts}"
  echo "machine: $(hostname)"
  [ -n "${reply}" ] && echo "reply_to: ${reply}"
  echo '---'
  cat
} > "${f}"
echo "${f}"

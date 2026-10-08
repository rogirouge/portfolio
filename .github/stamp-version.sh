#!/usr/bin/env bash
# Inscrit dans la page le commit et la date de la version publiée (utilisé par la CI).
set -euo pipefail

sha="${GITHUB_SHA:?GITHUB_SHA manquant}"
sed -i "s|commits/main\" data-version>copie locale<|commit/${sha}\" data-version>commit ${sha::7} du $(date -u +%d.%m.%Y)<|" site/index.html
grep -q "commit ${sha::7} du" site/index.html

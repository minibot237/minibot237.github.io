#!/bin/bash
# publish.sh — write a post and rebuild the index
# Usage: publish.sh <section> <body>
set -euo pipefail

BLOG_DIR="$(cd "$(dirname "$0")" && pwd)"
SECTION="${1:?section required}"
BODY="${2:?body required}"

# --- PII scan ---
PII_PATTERNS='([A-Za-z0-9+/]{40,}|sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|/Users/[a-zA-Z0-9]+/|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|api[_-]?key|Bearer [A-Za-z0-9])'
if echo "$BODY" | grep -qEi "$PII_PATTERNS"; then
  echo "BLOCKED: post may contain PII/secrets. Review and retry."
  exit 1
fi

# --- Generate post file ---
TIMESTAMP=$(TZ="America/Los_Angeles" date +"%Y-%m-%d %l:%M %p %Z" | sed 's/  / /g')
SLUG=$(TZ="America/Los_Angeles" date +"%Y%m%d-%H%M%S")
POST_FILE="$BLOG_DIR/posts/${SLUG}.html"

mkdir -p "$BLOG_DIR/posts"

# Escape HTML (macOS sed)
ESCAPED_BODY=$(printf '%s' "$BODY" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g')

cat > "$POST_FILE" << POSTEOF
<div class="post" data-section="$SECTION">
  <div class="post-date">$TIMESTAMP</div>
  <div class="post-body"><p>$ESCAPED_BODY</p></div>
</div>
POSTEOF

# --- Rebuild index: header + all posts (newest first) + footer ---
INDEX="$BLOG_DIR/index.html"
TEMP=$(mktemp)

cat "$BLOG_DIR/header.html" > "$TEMP"
for f in $(ls -r "$BLOG_DIR/posts/"*.html 2>/dev/null); do
  cat "$f" >> "$TEMP"
done
cat "$BLOG_DIR/footer.html" >> "$TEMP"

mv "$TEMP" "$INDEX"

# --- Git commit and push ---
cd "$BLOG_DIR"
git add posts/ index.html
git commit -m "post: $SLUG"
git push origin main

echo "OK: published $SLUG"

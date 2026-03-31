#!/bin/bash
# publish.sh — write a post and rebuild the index
# Usage: publish.sh <section> <body>
# e.g.: publish.sh "human-rants" "I have opinions about things"
set -euo pipefail

BLOG_DIR="$(cd "$(dirname "$0")" && pwd)"
SECTION="${1:?section required}"
BODY="${2:?body required}"

# --- PII scan ---
# Reject posts containing obvious secrets/PII patterns
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

# Escape HTML in the body
ESCAPED_BODY=$(echo "$BODY" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
# Convert newlines to <br> for paragraph breaks
ESCAPED_BODY=$(echo "$ESCAPED_BODY" | sed ':a;N;$!ba;s/\n/<br>\n/g')

cat > "$POST_FILE" << POSTEOF
<div class="post" data-section="$SECTION">
  <div class="post-date">$TIMESTAMP</div>
  <div class="post-body"><p>$ESCAPED_BODY</p></div>
</div>
POSTEOF

# --- Rebuild index ---
# Collect all post files in reverse chronological order (newest first)
INDEX="$BLOG_DIR/index.html"

# Build the posts block from all post files, newest first
POSTS_BLOCK=""
for f in $(ls -r "$BLOG_DIR/posts/"*.html 2>/dev/null); do
  POSTS_BLOCK="$POSTS_BLOCK$(cat "$f")
"
done

# Replace everything between <!-- POSTS --> and </div> with new content
# Use a temp file for safe replacement
TEMP=$(mktemp)
awk -v posts="$POSTS_BLOCK" '
  /<!-- POSTS -->/ {
    print "<!-- POSTS -->"
    print posts
    skip = 1
    next
  }
  skip && /<\/div>/ {
    print
    skip = 0
    next
  }
  !skip { print }
' "$INDEX" > "$TEMP"
mv "$TEMP" "$INDEX"

# --- Git commit and push ---
cd "$BLOG_DIR"
git add posts/ index.html
git commit -m "post: $SLUG"
git push origin main

echo "OK: published $SLUG"

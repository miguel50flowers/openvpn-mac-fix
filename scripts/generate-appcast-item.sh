#!/bin/bash
# Generates an appcast <item> XML block for a given version.
# Usage: ./scripts/generate-appcast-item.sh 2.0.8
#
# Reads CHANGELOG.md, extracts the section for the given version,
# converts markdown to basic HTML, and outputs a complete <item> block
# with placeholders for CI to fill in (signature, length, build number).

set -euo pipefail

VERSION="${1:?Usage: $0 <version>}"
CHANGELOG="CHANGELOG.md"
REPO_URL="https://github.com/miguel50flowers/openvpn-mac-fix"

if [[ ! -f "$CHANGELOG" ]]; then
    echo "Error: $CHANGELOG not found" >&2
    exit 1
fi

# Extract the section between ## [$VERSION] and the next ## [
section=$(awk -v ver="$VERSION" '
    /^## \[/ {
        if (found) exit
        if ($0 ~ "\\[" ver "\\]") found=1
        next
    }
    found { print }
' "$CHANGELOG")

if [[ -z "$section" ]]; then
    echo "Error: No changelog entry found for version $VERSION" >&2
    exit 1
fi

# Convert markdown to basic HTML
html=$(echo "$section" | awk '
    BEGIN { in_list = 0 }
    /^### / {
        if (in_list) { print "</ul>"; in_list = 0 }
        sub(/^### /, "")
        print "<h3>" $0 "</h3>"
        next
    }
    /^- / {
        if (!in_list) { print "<ul>"; in_list = 1 }
        sub(/^- /, "")
        print "<li>" $0 "</li>"
        next
    }
    /^[[:space:]]*$/ { next }
    /^  - / {
        # Sub-items: flatten into the same list
        if (!in_list) { print "<ul>"; in_list = 1 }
        sub(/^  - /, "")
        print "<li>" $0 "</li>"
        next
    }
    END { if (in_list) print "</ul>" }
')

# Generate pubDate in RFC 2822 format
pubdate=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")

cat <<EOF
        <item>
            <title>Version ${VERSION}</title>
            <description><![CDATA[
                ${html}
            ]]></description>
            <pubDate>${pubdate}</pubDate>
            <sparkle:version>__BUILD_NUMBER__</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
            <enclosure
                url="${REPO_URL}/releases/download/v${VERSION}/VPNFix-${VERSION}.dmg"
                type="application/octet-stream"
                sparkle:edSignature="__ED_SIGNATURE__"
                length="__DMG_LENGTH__"
            />
        </item>
EOF

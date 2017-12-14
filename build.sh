#!/bin/sh

# This script builds Itsycal for distribution.
# It first builds the app and then creates two
# ZIP files and a Sparkle appcast XML file which
# it places on the Desktop. Those files can then
# all be uploaded to the web.

# Exit with error if any subcommand fails:
set -o errexit

# Get the bundle version from the plist.
PLIST_FILE="Itsycal/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $PLIST_FILE)

if [ ! -z "$(git status --porcelain)" ]; then
    >&2 echo "Error: must be a clean working copy"
    exit 1
fi

# Set up file names and paths.
BUILD_PATH=$(mktemp -d "$TMPDIR/Itsycal.XXXXXX")
ZIP_NAME="Itsycal-$VERSION.zip"
ZIP_PATH1="$HOME/Desktop/$ZIP_NAME"
ZIP_PATH2="$HOME/Desktop/Itsycal.zip"
XML_PATH="$HOME/Desktop/itsycal.xml"

# Build Itsycal in a temporary build location.
xcodebuild -scheme Itsycal -configuration Release -derivedDataPath "$BUILD_PATH" build

# Tag release in git
git tag v$VERSION
git push --tags origin master

# Go into the temporary build directory.
cd "$BUILD_PATH/Build/Products/Release"

# Compress the app.
rm -f "$ZIP_PATH1"
rm -f "$ZIP_PATH2"
zip -r -y "$ZIP_PATH1" Itsycal.app
cp "$ZIP_PATH1" "$ZIP_PATH2"

# Get the date and zip file size for the Sparkle XML.
DATE=$(TZ=GMT date)
FILESIZE=$(stat -f "%z" "$ZIP_PATH1")

# Make the Sparkle appcast XML file.
cat > "$XML_PATH" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss
    version="2.0"
    xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
    xmlns:dc="http://purl.org/dc/elements/1.1/" >
<channel>
<title>Itsycal Changelog</title>
<link>https://s3.amazonaws.com/itsycal/itsycal.xml</link>
<description>Most recent changes</description>
<language>en</language>
<item>
<title>Version $VERSION</title>
<sparkle:minimumSystemVersion>10.12</sparkle:minimumSystemVersion>
<sparkle:releaseNotesLink>https://s3.amazonaws.com/itsycal/changelog.html</sparkle:releaseNotesLink>
<pubDate>$DATE +0000</pubDate>
<enclosure
    url="https://s3.amazonaws.com/itsycal/$ZIP_NAME"
    sparkle:version="$VERSION"
    length="$FILESIZE"
    type="application/octet-stream" />
</item>
</channel>
</rss>
EOF


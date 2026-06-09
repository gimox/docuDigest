#!/bin/bash
set -e

# Check if we are in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "Error: Not a git repository."
  exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
  echo "Warning: You have uncommitted changes. Please commit or stash them first."
  exit 1
fi

# Find the version line in pubspec.yaml
VERSION_LINE=$(grep "^version:" pubspec.yaml)
if [ -z "$VERSION_LINE" ]; then
  echo "Error: Could not find version line in pubspec.yaml"
  exit 1
fi

# Extract version name and build number (e.g., 1.0.0+1)
FULL_VERSION=${VERSION_LINE#version: }
FULL_VERSION=$(echo "$FULL_VERSION" | xargs) # strip whitespace

VERSION_NAME=${FULL_VERSION%+*}
BUILD_NUMBER=${FULL_VERSION#*+}

if [[ "$VERSION_NAME" == "$FULL_VERSION" ]]; then
  # No build number found
  VERSION_NAME=$FULL_VERSION
  BUILD_NUMBER=1
fi

# Split version components
IFS='.' read -r -a VERSION_PARTS <<< "$VERSION_NAME"
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

echo "Current version: $VERSION_NAME+$BUILD_NUMBER"
echo "Select the release type:"
echo "1) Minor (e.g., $MAJOR.$((MINOR + 1)).0)"
echo "2) Major (e.g., $((MAJOR + 1)).0.0)"
echo "3) Patch (e.g., $MAJOR.$MINOR.$((PATCH + 1)))"
read -rp "Enter choice [1-3]: " CHOICE

case $CHOICE in
  1)
    NEW_VERSION="$MAJOR.$((MINOR + 1)).0"
    ;;
  2)
    NEW_VERSION="$((MAJOR + 1)).0.0"
    ;;
  3)
    NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

NEW_BUILD=$((BUILD_NUMBER + 1))
NEW_FULL_VERSION="$NEW_VERSION+$NEW_BUILD"

echo "Bumping version to: $NEW_FULL_VERSION..."

# Update pubspec.yaml
perl -pi -e "s/^version:.*/version: $NEW_FULL_VERSION/" pubspec.yaml

echo "Updated pubspec.yaml successfully."

# Git commit, tag, and push
git add pubspec.yaml
git commit -m "chore: bump version to $NEW_VERSION"
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"

echo "Created git tag: v$NEW_VERSION"
echo ""
echo "To publish, run:"
echo "  git push origin HEAD && git push origin v$NEW_VERSION"
echo ""
read -rp "Do you want to push to remote origin now? (y/N): " PUSH_CHOICE
if [[ "$PUSH_CHOICE" =~ ^[Yy]$ ]]; then
  git push origin HEAD
  git push origin "v$NEW_VERSION"
  echo "Successfully pushed changes and tag to origin."
else
  echo "Changes committed and tagged locally. Remember to push them manually."
fi

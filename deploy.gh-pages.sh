#!/usr/bin/env bash
set -e


### Globals
# dbgEcho script name
SCRIPT_NAME_PRETTY="$(echo $0 | sed 's/\.\///')"

# For pushing commits
SOURCE_BRANCH="main"
GH_PAGES_BRANCH="gh-pages"

# Metadata for commits
COMMIT_MSG="next(auto): build and deploy to github pages"
COMMIT_AUTHOR_NAME="next deploy"
COMMIT_AUTHOR_EMAIL="github@podaboutli.st"


### Helper functions
# dbgEcho <level(INFO/WARN/ERROR)> <message>
dbgEcho () {
    echo "[$SCRIPT_NAME_PRETTY] $1: $2"
}

resetGit () {
    LAST_AUTHOR="$(git --no-pager log -1 --pretty=format:'%an')"

    if [[ "$LAST_AUTHOR" == "$COMMIT_AUTHOR_NAME" ]]; then
        dbgEcho "INFO" "Reverting to pre-deploy commit."
        git reset HEAD~
        dbgEcho "INFO" "Restoring original .gitignore"
        git checkout .gitignore
    fi
}


### --- Beginning of the main script ---

if [ ! -f "package.json" ]; then
    dbgEcho "ERROR" "File package.json not found."
    exit 1
fi

# Make sure the codebase is fully up-to-date before proceeding
dbgEcho "INFO" "Fetching upstream HEAD..."
git fetch --quiet --progress

STATUS="$(git status)"
if [[ "$STATUS" != *"nothing to commit"* ]]; then
    dbgEcho "ERROR" "Please commit or stash your changes before deploying."
    exit 1
fi

## Temporarily commit `out/`, subtree push to gh-pages branch, revert commit.

# TODO: Make sure the last two lines (reset HEAD~, checkout) run to ensure a
#       reset to a clean working state even if one of these commands fails.

dbgEcho "INFO" "Removing '/out/' from .gitignore"
sed -i 's/\/out\///' .gitignore

dbgEcho "INFO" "Removing node_modules/.cache"
rm -rf node_modules/.cache

dbgEcho "INFO" "Building static site..."
next build
next export

touch out/.nojekyll

dbgEcho "INFO" "Adding files for commit"
git add .gitignore out/

git commit \
    -m "$COMMIT_MSG" \
    --author="$COMMIT_AUTHOR_NAME <$COMMIT_AUTHOR_EMAIL>"

dbgEcho "INFO" "Pushing built files to the gh-pages branch"
git push origin `git subtree split --prefix out $SOURCE_BRANCH`:$GH_PAGES_BRANCH --force

resetGit
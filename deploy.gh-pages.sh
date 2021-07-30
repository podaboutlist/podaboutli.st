#!/usr/bin/env bash
set -e


### Global helper functions (required by everything!)
# dbgEcho <level(INFO/WARN/ERROR)> <message>
dbgEcho () {
    echo "[$SCRIPT_NAME_PRETTY] $1: $2"
}


### Sanity checks - are we running in a properly configured environment?
if [ ! -f "package.json" ]; then
    dbgEcho "ERROR" "File package.json not found"
    exit 1
fi

if [ -z $npm_package_repository_url ]; then
    dbgEcho "WARN" "Your package's repository URL is not set in package.json."
    dbgEcho "WARN" "This could cause issues force pushing."
    dbgEcho "WARN" "Find out how to set up a repo URL here: https://bit.ly/npmRepoURL"
fi


### Global variables
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
resetGit () {
    LAST_AUTHOR="$(git --no-pager log -1 --pretty=format:'%an')"

    if [[ "$LAST_AUTHOR" == "$COMMIT_AUTHOR_NAME" ]]; then
        dbgEcho "INFO" "Reverting to pre-deploy commit."
        git reset HEAD~
        dbgEcho "INFO" "Restoring original .gitignore"
        git checkout .gitignore
    fi
}


### -------------------------------------------- Beginning of the script proper
# Make sure the codebase is fully up-to-date before proceeding
dbgEcho "INFO" "Fetching upstream HEAD..."
git fetch --quiet --progress

STATUS="$(git status)"
if [[ "$STATUS" != *"nothing to commit"* ]]; then
    dbgEcho "ERROR" "Please commit or stash your changes before deploying."
    exit 1
fi

## Temporarily commit `out/`, subtree push to gh-pages branch, revert commit.
# TODO: Make sure the `resetGit` function executes if an error occurs

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
if [ ! -z "$npm_package_repository_url" ]; then
    dbgEcho "INFO" "Checking if the $GH_PAGES_BRANCH exists on our remote"
    TARGET_BRANCH_EXISTS="$(git ls-remote --heads "$npm_package_repository_url" $GH_PAGES_BRANCH)"

    if [ -z "$TARGET_BRANCH_EXISTS" ]; then
        dbgEcho "INFO" "Target $GH_PAGES_BRANCH branch not found on remote"
        dbgEcho "INFO" "Pushing a new branch."
        git subtree push --prefix "out" origin $GH_PAGES_BRANCH
    fi
else
    # Target branch __does__ exist, or we're just guessing since we don't have
    # a URL for the remote repo.
    # Use some git black magic to force push the subtree and cross our fingers it works
    dbgEcho "INFO" "Force pushing latest build to $GH_PAGES_BRANCH"
    git push origin `git subtree split --prefix "out" $SOURCE_BRANCH`:$GH_PAGES_BRANCH --force
fi

# Remove out/ commit, reset .gitignore
resetGit
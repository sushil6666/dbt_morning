#!/bin/bash
# Install pre-commit hooks

set -e

echo "Setting up pre-commit hooks..."

chmod +x .husky/pre-commit
mkdir -p .git/hooks
cp .husky/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

echo "✅ Pre-commit hook installed successfully!"
echo ""
echo "The pre-commit hook will now automatically:"
echo "  • Run dbt tests on changed files"
echo "  • Block commits if tests fail"
echo "  • Display test results before committing"
echo ""
echo "To bypass the hook (not recommended): git commit --no-verify"
echo "To uninstall: rm .git/hooks/pre-commit"

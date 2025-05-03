# 1. Create a health-check script
cat <<'EOF' > ~/.git-check
#!/usr/bin/env bash
# git ck: Universal health check script for GitHub & Bitbucket
set -euo pipefail
trap 'echo "💥 Command \"$BASH_COMMAND\" failed"; exit 1' ERR

remote=${1:-origin}

echo "🔍 Checking Git version:"
git --version

echo
echo "=== 1. Branch & Upstream ==="
# Get current branch name
branch=$(git rev-parse --abbrev-ref HEAD)
echo "• Branch: $branch"

# Check if an upstream is set
if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u})
  echo "• Upstream: $upstream"
  # Fetch remote updates quietly
  git fetch -q "$remote"
  # Count how many commits we're behind/ahead
  counts=$(git rev-list --left-right --count "$upstream"...HEAD)
  behind=${counts%%	*}
  ahead=${counts##*	}
  echo "• Behind/Ahead: $behind/$ahead"
else
  echo "⚠️ No upstream set for this branch"
fi
# Show short status
git status -sb

echo
echo "=== 2. Remotes & Authentication ==="
# Helper to extract host from a URL
parse_host() { echo "$1" | sed -E 's#(ssh://)?git@?([^/:]+).*#\2#'; }

# Loop through all remotes
for r in $(git remote); do
  url=$(git remote get-url "$r")
  host=$(parse_host "$url")
  echo "• Remote '$r' → $url (Host: $host)"
  
  if [[ $url =~ ^git@|^ssh:// ]]; then
    echo "  Testing SSH..."
    # Run ssh and capture output, ignore exit code
    ssh_output=$(ssh -T "git@$host" 2>&1 || true)
    # Check for success message
    if echo "$ssh_output" | grep -Eqi "successfully authenticated|authenticated"; then
      echo "  ✅ SSH OK"
    else
      echo "  ❌ SSH failed — output was:"
      echo "     $ssh_output"
      exit 1
    fi
  else
    echo "  Testing HTTPS..."
    # HTTPS test: try listing remote heads
    if git ls-remote --heads "$r" &>/dev/null; then
      echo "  ✅ HTTPS OK"
    else
      echo "  ❌ Token/App Password invalid — please update credentials"
      exit 1
    fi
  fi
done

echo
echo "=== 3. Git LFS ==="
# Check if git-lfs is installed
if command -v git-lfs &>/dev/null; then
  # Verify LFS endpoint configuration
  if git lfs env | grep -q "Endpoint"; then
    git lfs env | grep "Endpoint"
  else
    echo "⚠️ No LFS endpoint detected"
  fi
else
  echo "⚠️ git-lfs not installed"
fi

echo
echo "=== 4. GPG Signature ==="
# Show GPG signature of the latest commit if available
if git log -1 --show-signature 2>/dev/null | grep -q "gpg:"; then
  git log -1 --show-signature | sed -n '1,5p'
else
  echo "⚠️ Latest commit is not signed or signature unavailable"
fi

echo
echo "=== 5. Staged Changes Size ==="
# Warn if staged changes exceed 100,000 lines
size=$(git diff --cached --numstat | awk '{sum+=$1} END {print sum}')
if (( size > 100000 )); then
  echo "⚠️ Staged changes are $size lines—possible large files!"
else
  echo "✅ Staged changes: $size lines"
fi

echo
echo "✨ All checks passed. You can safely run git push!"

EOF
chmod +x ~/.git-check

# 2. Set a global alias for the health check
git config --global alias.ck '!bash ~/.git-check'

# 3. Create a Git template (will be copied into each new repo)
mkdir -p ~/.git-template/hooks
cat <<'EOF' > ~/.git-template/hooks/pre-push
#!/usr/bin/env bash
sh ~/.git-check        # Run health check before push
EOF
chmod +x ~/.git-template/hooks/pre-push

# 4. Configure Git to use this template for new repositories
git config --global init.templatedir '~/.git-template'

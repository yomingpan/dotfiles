# 1. Create a health-check script
cat <<'EOF' > ~/.git-check
#!/usr/bin/env bash
set -e
echo "🔍 Checking branch / upstream:" ; git status -sb
echo "🔍 Checking remote:" ; git remote -v | head -n1
echo "🔍 Testing credentials:" ; git ls-remote -h &>/dev/null && echo "✅ OK" || {
  echo "❌ Credential error" ; exit 1 ; }
EOF
chmod +x ~/.git-check

# 2. Set a global alias for the health check
git config --global alias.ck '!sh ~/.git-check'

# 3. Create a Git template (will be copied into each new repo)
mkdir -p ~/.git-template/hooks
cat <<'EOF' > ~/.git-template/hooks/pre-push
#!/usr/bin/env bash
sh ~/.git-check        # Run health check before push
EOF
chmod +x ~/.git-template/hooks/pre-push

# 4. Configure Git to use this template for new repositories
git config --global init.templatedir '~/.git-template'

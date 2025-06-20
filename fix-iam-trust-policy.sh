#!/bin/bash

# Fix IAM role trust policy for GitHub Actions OIDC

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

APP_NAME="gmfam"
ROLE_NAME="${APP_NAME}-github-actions-role"

print_info "Fixing IAM role trust policy for GitHub Actions OIDC..."

# Get GitHub username
if gh auth status >/dev/null 2>&1; then
    GITHUB_USERNAME=$(gh api user --jq '.login')
    print_info "GitHub username: $GITHUB_USERNAME"
else
    print_error "GitHub CLI not authenticated. Please run 'gh auth login' first."
    exit 1
fi

# Get repository name from git remote
if git remote get-url origin >/dev/null 2>&1; then
    REPO_URL=$(git remote get-url origin)
    GITHUB_REPO=$(echo "$REPO_URL" | sed 's/.*github\.com[/:]\([^/]*\/[^/]*\)\.git.*/\1/' | sed 's/\.git$//' | cut -d'/' -f2)
    print_info "Repository name: $GITHUB_REPO"
else
    print_error "Not in a git repository or no origin remote found"
    exit 1
fi

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_info "AWS Account ID: $ACCOUNT_ID"

# Create corrected trust policy
print_info "Creating corrected trust policy..."
cat > trust-policy-fix.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:${GITHUB_USERNAME}/${GITHUB_REPO}:*"
                }
            }
        }
    ]
}
EOF

# Update the IAM role trust policy
print_info "Updating IAM role trust policy..."
if aws iam update-assume-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-document file://trust-policy-fix.json; then
    print_success "IAM role trust policy updated successfully"
else
    print_error "Failed to update IAM role trust policy"
    exit 1
fi

# Clean up
rm -f trust-policy-fix.json

# Verify the fix
print_info "Verifying the fix..."
TRUST_POLICY=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json)

if echo "$TRUST_POLICY" | grep -q "repo:${GITHUB_USERNAME}/${GITHUB_REPO}"; then
    print_success "Trust policy now includes correct repository: ${GITHUB_USERNAME}/${GITHUB_REPO}"
else
    print_error "Trust policy still doesn't include the correct repository"
    exit 1
fi

print_success "Trust policy fix completed! GitHub Actions should now be able to assume the role."
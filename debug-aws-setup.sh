#!/bin/bash

# Debug script to check AWS setup for GitHub Actions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

APP_NAME="gmfam"

print_header "AWS Setup Debug Report"

# Check AWS CLI
print_info "Checking AWS CLI..."
if aws --version 2>/dev/null; then
    print_success "AWS CLI is installed"
else
    print_error "AWS CLI not found"
    exit 1
fi

# Check AWS credentials
print_info "Checking AWS credentials..."
if aws sts get-caller-identity >/dev/null 2>&1; then
    account_id=$(aws sts get-caller-identity --query Account --output text)
    user_arn=$(aws sts get-caller-identity --query Arn --output text)
    print_success "AWS credentials are valid"
    print_info "Account: $account_id"
    print_info "User: $user_arn"
else
    print_error "AWS credentials are not configured or invalid"
    exit 1
fi

# Check GitHub CLI
print_info "Checking GitHub CLI..."
if gh --version >/dev/null 2>&1; then
    print_success "GitHub CLI is installed"
    
    if gh auth status >/dev/null 2>&1; then
        github_user=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
        print_success "GitHub CLI is authenticated as: $github_user"
    else
        print_error "GitHub CLI is not authenticated"
    fi
else
    print_error "GitHub CLI not found"
fi

print_header "OIDC Provider Check"

# Check OIDC provider
oidc_arn="arn:aws:iam::${account_id}:oidc-provider/token.actions.githubusercontent.com"
print_info "Checking OIDC provider: $oidc_arn"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$oidc_arn" >/dev/null 2>&1; then
    print_success "GitHub OIDC provider exists"
    
    # Get thumbprints
    thumbprints=$(aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$oidc_arn" --query 'ThumbprintList' --output text)
    print_info "Thumbprints: $thumbprints"
    
    # Get client IDs
    client_ids=$(aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$oidc_arn" --query 'ClientIDList' --output text)
    print_info "Client IDs: $client_ids"
else
    print_error "GitHub OIDC provider does not exist"
    print_info "You need to create it with:"
    print_info "aws iam create-open-id-connect-provider --url https://token.actions.githubusercontent.com --client-id-list sts.amazonaws.com --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1"
fi

print_header "IAM Role Check"

# Check IAM role
role_name="${APP_NAME}-github-actions-role"
print_info "Checking IAM role: $role_name"

if aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
    print_success "IAM role exists"
    
    # Get role ARN
    role_arn=$(aws iam get-role --role-name "$role_name" --query 'Role.Arn' --output text)
    print_info "Role ARN: $role_arn"
    
    # Check trust policy
    print_info "Checking trust policy..."
    trust_policy=$(aws iam get-role --role-name "$role_name" --query 'Role.AssumeRolePolicyDocument' --output json)
    
    if echo "$trust_policy" | grep -q "token.actions.githubusercontent.com"; then
        print_success "Trust policy includes GitHub OIDC"
    else
        print_error "Trust policy does not include GitHub OIDC"
    fi
    
    # Check for repository restriction
    if echo "$trust_policy" | grep -q "repo:"; then
        repo_pattern=$(echo "$trust_policy" | grep -o "repo:[^\"]*" || echo "not found")
        print_info "Repository pattern: $repo_pattern"
    else
        print_warning "No repository restriction found in trust policy"
    fi
    
    # Check role policies
    print_info "Checking attached policies..."
    inline_policies=$(aws iam list-role-policies --role-name "$role_name" --query 'PolicyNames' --output text)
    if [[ -n "$inline_policies" && "$inline_policies" != "None" ]]; then
        print_success "Inline policies: $inline_policies"
    else
        print_warning "No inline policies found"
    fi
    
    attached_policies=$(aws iam list-attached-role-policies --role-name "$role_name" --query 'AttachedPolicies[].PolicyName' --output text)
    if [[ -n "$attached_policies" && "$attached_policies" != "None" ]]; then
        print_success "Attached policies: $attached_policies"
    else
        print_warning "No attached policies found"
    fi
    
else
    print_error "IAM role does not exist"
    print_info "Role should be created by the setup script"
fi

print_header "GitHub Repository Check"

# Check GitHub repository and secrets
if gh auth status >/dev/null 2>&1; then
    # Try to determine repository from git remote
    if git remote get-url origin >/dev/null 2>&1; then
        repo_url=$(git remote get-url origin)
        repo_name=$(echo "$repo_url" | sed 's/.*github\.com[/:]\([^/]*\/[^/]*\)\.git.*/\1/' | sed 's/\.git$//')
        print_info "Current repository: $repo_name"
        
        # Check secrets
        print_info "Checking GitHub secrets..."
        
        critical_secrets=("AWS_ARN_OIDC_ACCESS" "ECR_REPOSITORY" "LIGHTSAIL_SERVICE_NAME")
        for secret in "${critical_secrets[@]}"; do
            if gh secret list --repo "$repo_name" 2>/dev/null | grep -q "^$secret"; then
                print_success "$secret is set"
            else
                print_error "$secret is missing"
            fi
        done
        
        # Try to get the actual value of AWS_ARN_OIDC_ACCESS (won't show the value but will show if it exists)
        if gh api "repos/$repo_name/actions/secrets/AWS_ARN_OIDC_ACCESS" >/dev/null 2>&1; then
            print_success "AWS_ARN_OIDC_ACCESS secret is accessible via API"
        else
            print_error "AWS_ARN_OIDC_ACCESS secret is not accessible via API"
        fi
        
    else
        print_warning "Not in a git repository or no origin remote found"
    fi
else
    print_warning "GitHub CLI not authenticated, skipping repository checks"
fi

print_header "Recommendations"

echo "If you're getting authentication errors in GitHub Actions:"
echo "1. Make sure the OIDC provider exists (see above)"
echo "2. Make sure the IAM role exists with correct trust policy"
echo "3. Make sure AWS_ARN_OIDC_ACCESS secret contains the correct role ARN"
echo "4. Make sure the trust policy includes your specific repository"
echo
echo "Expected role ARN format: arn:aws:iam::${account_id}:role/${role_name}"
if [[ -n "$role_arn" ]]; then
    echo "Your role ARN: $role_arn"
fi
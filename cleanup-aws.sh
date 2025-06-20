#!/bin/bash

# AWS Infrastructure Cleanup Script for GMFam Application
# This script removes all AWS resources created by setup-aws.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_NAME="gmfam"

# Function to print colored output
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

# Function to prompt for user input
prompt_user() {
    local prompt="$1"
    local var_name="$2"
    local default_value="$3"
    
    if [[ -n "$default_value" ]]; then
        prompt="$prompt (default: $default_value)"
    fi
    
    echo -n "$prompt: "
    read user_input
    
    if [[ -z "$user_input" && -n "$default_value" ]]; then
        user_input="$default_value"
    fi
    
    eval "$var_name='$user_input'"
}

# Function to delete RDS database
delete_database() {
    print_header "Deleting RDS Database"
    
    local db_instance_id="${APP_NAME}-db"
    local db_subnet_group_name="${APP_NAME}-db-subnet-group"
    local db_security_group_name="${APP_NAME}-db-sg"
    
    # Delete RDS instance
    print_info "Deleting RDS instance..."
    aws rds delete-db-instance \
        --db-instance-identifier "$db_instance_id" \
        --skip-final-snapshot \
        --delete-automated-backups \
        >/dev/null 2>&1 && print_success "RDS instance deletion initiated" || print_warning "RDS instance not found or already deleted"
    
    # Wait for RDS instance to be deleted
    print_info "Waiting for RDS instance to be deleted (this may take several minutes)..."
    aws rds wait db-instance-deleted --db-instance-identifier "$db_instance_id" 2>/dev/null || true
    
    # Delete DB subnet group
    print_info "Deleting DB subnet group..."
    aws rds delete-db-subnet-group \
        --db-subnet-group-name "$db_subnet_group_name" \
        >/dev/null 2>&1 && print_success "DB subnet group deleted" || print_warning "DB subnet group not found"
    
    # Get and delete security group
    local vpc_id=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
    
    if [[ "$vpc_id" != "None" ]]; then
        local db_sg_id=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$db_security_group_name" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")
        
        if [[ "$db_sg_id" != "None" ]]; then
            print_info "Deleting database security group..."
            aws ec2 delete-security-group --group-id "$db_sg_id" >/dev/null 2>&1 && print_success "Database security group deleted" || print_warning "Failed to delete security group"
        fi
    fi
}

# Function to delete Lightsail instance
delete_lightsail_instance() {
    print_header "Deleting Lightsail Instance"
    
    local instance_name="${APP_NAME}-server"
    
    # Delete Lightsail instance
    print_info "Deleting Lightsail instance..."
    aws lightsail delete-instance \
        --instance-name "$instance_name" \
        >/dev/null 2>&1 && print_success "Lightsail instance deleted" || print_warning "Lightsail instance not found"
    
    # Delete SSH key pair
    print_info "Deleting SSH key pair..."
    aws lightsail delete-key-pair \
        --key-pair-name "${APP_NAME}-key" \
        >/dev/null 2>&1 && print_success "SSH key pair deleted from AWS" || print_warning "SSH key pair not found in AWS"
    
    # Remove local SSH key file
    if [[ -f "${APP_NAME}-key.pem" ]]; then
        rm -f "${APP_NAME}-key.pem"
        print_success "Local SSH key file deleted"
    fi
}

# Function to delete IAM role
delete_github_iam_role() {
    print_header "Deleting IAM Role"
    
    local role_name="${APP_NAME}-github-actions-role"
    local policy_name="${APP_NAME}-github-actions-policy"
    
    # Delete role policy
    print_info "Deleting IAM role policy..."
    aws iam delete-role-policy \
        --role-name "$role_name" \
        --policy-name "$policy_name" \
        >/dev/null 2>&1 && print_success "IAM role policy deleted" || print_warning "IAM role policy not found"
    
    # Delete IAM role
    print_info "Deleting IAM role..."
    aws iam delete-role \
        --role-name "$role_name" \
        >/dev/null 2>&1 && print_success "IAM role deleted" || print_warning "IAM role not found"
}

# Function to clean up local files
cleanup_local_files() {
    print_header "Cleaning Up Local Files"
    
    # Remove generated files
    local files_to_remove=(
        "github-secrets.txt"
        "config/config.prod.yaml"
        "${APP_NAME}-key.pem"
    )
    
    for file in "${files_to_remove[@]}"; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
            print_success "Removed: $file"
        fi
    done
}

# Function to generate cleanup summary
generate_cleanup_summary() {
    print_header "Cleanup Summary"
    
    print_success "AWS infrastructure cleanup completed!"
    echo
    echo "Resources Removed:"
    echo "=================="
    echo "✅ Lightsail Instance"
    echo "✅ RDS PostgreSQL Database"
    echo "✅ IAM Role for GitHub Actions"
    echo "✅ SSH Key Pair"
    echo "✅ Local configuration files"
    echo
    echo "Manual Steps Required:"
    echo "====================="
    echo "1. Remove GitHub secrets from your repository"
    echo "2. Check AWS Console to ensure all resources are deleted"
    echo "3. Verify no unexpected charges on your AWS bill"
    echo
    print_warning "Double-check your AWS Console to ensure all resources are deleted"
    print_info "This will stop all charges related to this deployment"
}

# Main execution
main() {
    print_header "GMFam AWS Infrastructure Cleanup"
    echo
    
    print_warning "This will permanently delete all AWS resources for your application"
    print_warning "This action cannot be undone!"
    echo
    
    prompt_user "Are you sure you want to delete all AWS resources? (type 'yes' to confirm)" "confirm_delete"
    
    if [[ "$confirm_delete" != "yes" ]]; then
        print_info "Cleanup cancelled by user"
        exit 0
    fi
    
    print_warning "Starting cleanup in 5 seconds... Press Ctrl+C to cancel"
    sleep 5
    
    # Execute cleanup steps
    delete_database
    delete_lightsail_instance
    delete_github_iam_role
    cleanup_local_files
    generate_cleanup_summary
    
    print_success "Cleanup completed successfully! 🧹"
}

# Execute main function
main "$@"
# GMFam AWS Deployment Guide

This guide will help you deploy your GMFam application to AWS with minimal technical expertise. The entire process is automated through scripts that create all necessary AWS resources.

## 🚀 Quick Start

1. **Run the setup script**:
   ```bash
   ./setup-aws.sh
   ```

2. **Follow the prompts** to configure your deployment

3. **Add GitHub secrets** (the script will tell you exactly what to add)

4. **Push your code** to trigger automatic deployment

Your application will be running on AWS in about 20 minutes! 🎉

## 📋 Prerequisites

- **AWS Account**: You'll need an AWS account with billing enabled
- **GitHub Repository**: Your code should be in a GitHub repository
- **Command Line Access**: Terminal/Command Prompt on Mac, Linux, or Windows

## 💰 Cost Estimate

Running GMFam on AWS will cost approximately **$19/month**:
- Lightsail Instance (micro): ~$3.50/month
- RDS PostgreSQL Database: ~$15/month  
- Data Transfer: ~$0.50/month

## 📚 Detailed Setup Instructions

### Step 1: Download and Run Setup Script

1. **Clone or download** your repository to your local machine
2. **Open terminal** and navigate to your project directory
3. **Run the setup script**:
   ```bash
   ./setup-aws.sh
   ```

### Step 2: Answer Setup Questions

The script will ask you several questions:

#### AWS Configuration
- **AWS Access Key ID**: Get this from AWS Console → IAM → Your User → Security Credentials
- **AWS Secret Access Key**: Created alongside your Access Key ID
- **AWS Region**: Choose the region closest to your users (default: us-east-1)

#### Application Configuration
- **Application Name**: Your app name (default: gmfam)
- **Domain Name**: Optional - leave empty to use IP address
- **Email Address**: Your email for notifications and admin account
- **GitHub Username**: Your GitHub username
- **GitHub Repository**: Your repository name

#### Database Configuration
- **Database Name**: Automatically generated (e.g., gmfam_prod)
- **Database Username**: Automatically generated
- **Database Password**: Automatically generated (secure)

### Step 3: Add GitHub Secrets

After the script completes, it will show you a list of secrets to add to GitHub:

1. **Go to your GitHub repository**
2. **Click**: Settings → Secrets and variables → Actions
3. **Add each secret** shown in the script output

**Important GitHub Secrets**:
- `AWS_ARN_OIDC_ACCESS`: IAM role for deployments
- `LIGHTSAIL_HOST`: Your server's IP address
- `LIGHTSAIL_SSH_KEY`: SSH key for server access
- `PAGODA_DATABASE_CONNECTION`: Database connection string
- `PAGODA_APP_HOST`: Your application URL
- `PAGODA_APP_ENCRYPTIONKEY`: Security encryption key

### Step 4: Deploy Your Application

1. **Commit and push** your code to the main branch
2. **Go to GitHub Actions** tab in your repository
3. **Watch the deployment** process (takes about 5-10 minutes)
4. **Access your application** at the provided IP address

## 🔧 What the Setup Script Creates

### AWS Resources

1. **Lightsail Instance**
   - Ubuntu 20.04 server
   - Micro instance ($3.50/month)
   - Configured firewall (ports 22, 80, 443, 8000)
   - SSH key pair for secure access

2. **RDS PostgreSQL Database**
   - PostgreSQL 15.5
   - db.t3.micro instance ($15/month)
   - 20GB storage with 7-day backups
   - Secure networking (private access only)

3. **IAM Role & Policies**
   - GitHub Actions OIDC integration
   - Secure deployment permissions
   - No long-term AWS keys needed

4. **Security Groups**
   - Database access only from application server
   - Web traffic allowed on standard ports
   - SSH access for maintenance

### Local Files

- `github-secrets.txt`: All GitHub secrets you need to add
- `config/config.prod.yaml`: Production configuration file
- `gmfam-key.pem`: SSH private key (keep secure!)
- Setup log file for troubleshooting

## 🔒 Security Features

- **No hardcoded passwords**: All passwords auto-generated
- **Encrypted database**: RDS encryption at rest
- **OIDC Authentication**: No long-term AWS keys in GitHub
- **Private database**: Only accessible from application server
- **SSH key authentication**: Secure server access

## 📱 Accessing Your Application

After deployment, you can access your application at:
- **Web Interface**: `http://YOUR_IP:8000`
- **Admin Panel**: `http://YOUR_IP:8000/admin` (if enabled)

## 🐛 Troubleshooting

### Common Issues

1. **AWS Credentials Error**
   - Verify your AWS Access Key and Secret Key
   - Ensure your AWS user has AdministratorAccess policy

2. **GitHub Actions Failing**
   - Check all GitHub secrets are added correctly
   - Verify the SSH key content (no extra spaces/newlines)

3. **Database Connection Issues**
   - Ensure RDS instance is in "Available" state
   - Check security group allows PostgreSQL port (5432)

4. **Application Not Loading**
   - Check GitHub Actions logs for deployment errors
   - SSH into server: `ssh -i gmfam-key.pem ubuntu@YOUR_IP`
   - Check service status: `sudo systemctl status gmfam`

### Getting Help

1. **Check setup log**: Look for any errors in the generated log file
2. **AWS Console**: Verify all resources were created properly
3. **GitHub Actions**: Review deployment logs for specific errors
4. **SSH Access**: Connect to server to check application logs

## 🧹 Cleanup / Removal

To remove all AWS resources and stop billing:

```bash
./cleanup-aws.sh
```

**Warning**: This permanently deletes everything and cannot be undone!

## 🔄 Making Changes

### Code Updates
- Simply push to your main branch
- GitHub Actions will automatically deploy changes
- Zero-downtime deployments with automatic rollback on failure

### Configuration Changes
- Update `config/config.prod.yaml` for production settings
- Update GitHub secrets for environment variables
- Restart application: SSH in and run `sudo systemctl restart gmfam`

### Database Changes
- Database migrations run automatically on deployment
- Backups are taken daily (7-day retention)
- Can restore from AWS RDS console if needed

## 📊 Monitoring

### Application Health
- Health check endpoint: `http://YOUR_IP:8000/health`
- GitHub Actions monitors deployments
- Email notifications on deployment failure (if configured)

### AWS Monitoring
- AWS CloudWatch for basic metrics
- RDS monitoring for database performance
- Lightsail metrics for server performance

### Logs
- Application logs: `sudo journalctl -u gmfam -f`
- System logs: `sudo journalctl -f`
- Database logs: Available in AWS RDS console

## 🎯 Next Steps

After successful deployment:

1. **Set up domain name** (optional)
   - Purchase domain from Route 53 or external provider
   - Point domain to your Lightsail IP
   - Update `PAGODA_APP_HOST` GitHub secret

2. **Enable SSL/HTTPS** (recommended)
   - Use Let's Encrypt for free SSL certificates
   - Configure reverse proxy (nginx/Apache)
   - Update application to redirect HTTP → HTTPS

3. **Configure email** (optional)
   - Set up SES for transactional emails
   - Update mail configuration in GitHub secrets
   - Test registration/password reset emails

4. **Set up monitoring** (optional)
   - Configure CloudWatch alarms
   - Set up uptime monitoring (Pingdom, etc.)
   - Enable detailed application logging

## 🆘 Emergency Procedures

### Application Down
1. Check GitHub Actions for recent deployment failures
2. SSH into server: `ssh -i gmfam-key.pem ubuntu@YOUR_IP`
3. Check service: `sudo systemctl status gmfam`
4. Restart if needed: `sudo systemctl restart gmfam`
5. Check logs: `sudo journalctl -u gmfam -n 50`

### Database Issues
1. Check RDS status in AWS Console
2. Verify security groups allow database access
3. Test connection from application server
4. Check database logs in AWS Console

### Complete Restore
1. Use RDS automated backups to restore database
2. Redeploy application from known-good Git commit
3. Update DNS if using custom domain

---

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review AWS and GitHub documentation
3. Check community forums for similar issues
4. Consider hiring a DevOps consultant for complex setups

**Remember**: Keep your SSH keys and database credentials secure!
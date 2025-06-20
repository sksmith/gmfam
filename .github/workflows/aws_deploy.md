In today’s fast-paced development world, automation is the key to efficiency and reliability. This blog post will guide you through the process of setting up a GitHub Actions workflow to automate deployments to AWS Lightsail for your application. By the end of this guide, you’ll have a robust and efficient deployment pipeline that also keeps you informed through Slack notifications.

Prerequisites

Before we dive into creating the GitHub Actions workflow, let’s ensure you have the following prerequisites in place:

An AWS Lightsail account.
A GitHub repository where your application code is hosted.
An AWS IAM role (OIDC) with appropriate permissions for your GitHub Actions workflow.
Slack account (optional, but recommended for notifications).
Step 1: Understanding the Workflow File

We’ll start by understanding the GitHub Actions workflow file that defines our deployment process. This workflow is triggered when changes are pushed to the main branch or when pull requests are made to the main branch.

name: Exceed Backend workflow
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
This workflow has two main jobs: integration and deploy. The integration job runs on every push to the main branch and performs tasks like linting and building your application. The deploy job, on the other hand, is responsible for deploying your application to Lightsail when changes are pushed.

Step 2: Setting up AWS Lightsail and AWS CLI

Before we proceed with the workflow, make sure you have the AWS CLI installed on your GitHub Actions runner. We’ll also configure Lightsailctl for interacting with Lightsail services.

      - name: Upgrade AWS CLI version and setup lightsailctl
        run: |
          aws --version
          curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
          unzip awscliv2.zip
          sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
          which aws
          aws --version
          sudo curl "https://s3.us-west-2.amazonaws.com/lightsailctl/latest/linux-amd64/lightsailctl" -o "/usr/local/bin/lightsailctl"
          sudo chmod +x /usr/local/bin/lightsailctl
Step 3: Configuring AWS Credentials

You’ll need to configure AWS credentials to authenticate with AWS services. We’ll use an IAM role for this purpose.

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          role-to-assume: ${{ secrets.AWS_ARN_OICN_ACCESS }}
          role-session-name: Github
          aws-region: us-east-1
Step 4: Building and Pushing Docker Images

Your application likely runs in a Docker container. This step involves building your Docker image and pushing it to the Amazon Elastic Container Registry (ECR).

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Create Build and Tag tag
        env:
          IMAGE_TAG: latest
          IMAGE_SHA_TAG: ${{ github.sha }}
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        run: |
          docker build -t $ECR_REGISTRY/${{vars.ECR_REPOSITORY}}:$IMAGE_TAG .
          docker build -t $ECR_REGISTRY/${{vars.ECR_REPOSITORY}}:$IMAGE_SHA_TAG .
          docker push $ECR_REGISTRY/${{vars.ECR_REPOSITORY}}:$IMAGE_TAG
          docker push $ECR_REGISTRY/${{vars.ECR_REPOSITORY}}:$IMAGE_SHA_TAG
Step 5: Deploying to AWS Lightsail

Now comes the exciting part: deploying your application to AWS Lightsail. This step involves pushing your Docker image to Lightsail, updating the service, and creating a deployment.


      - name: Push the Docker Image to lightsail
        env: 
          IMAGE_SHA_TAG: ${{ github.sha }}
          IMAGE_URL: ${{vars.LIGHTSAIL_IMAGE}}:${{ github.sha }}
        run: >
          aws lightsail push-container-image
          --service-name ${{ vars.SERVICE_NAME }}
          --image $IMAGE_URL
          --region us-east-2
          --label git-push      
      - name: Save updated LIGHTSAIL_IMAGE_TAG 
        run: |
          echo "LIGHTSAIL_DOCKER_IMAGE=$(aws lightsail get-container-images --service-name ${{ vars.SERVICE_NAME }} --region us-east-2 | jq -r .containerImages[0].image)"  >> $GITHUB_ENV
      
      - name: Start New Deployment to Light Sail
        run: |
          aws lightsail create-container-service-deployment  --region us-east-2 \
          --service-name ${{vars.SERVICE_NAME}} \
          --output yaml \
          --containers "{
            \"${{vars.SERVICE_NAME}}\": {
              \"image\": \"$LIGHTSAIL_DOCKER_IMAGE\",
              \"environment\": {
                  \"VERSION\": \"${{github.run_number}}\"
                },
              \"ports\": {
                \"8000\": \"HTTP\"
              }
            }
          }" \
          --public-endpoint "{
            \"containerName\": \"${{vars.SERVICE_NAME}}\",
            \"containerPort\": 8000,
            \"healthCheck\": {
              \"path\": \"/healthcheck/liveness\",
              \"intervalSeconds\": 10
            }
          }"      - name: Push the Docker Image to lightsail
        env: 
          IMAGE_SHA_TAG: ${{ github.sha }}
          IMAGE_URL: ${{vars.LIGHTSAIL_IMAGE}}:${{ github.sha }}
        run: >
          aws lightsail push-container-image
          --service-name ${{ vars.SERVICE_NAME }}
          --image $IMAGE_URL
          --region us-east-2
          --label git-push
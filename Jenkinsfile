pipeline {
    agent any

    environment {
        AWS_REGION   = 'eu-north-1'
        ECR_REGISTRY = '710119226111.dkr.ecr.eu-north-1.amazonaws.com'
        ECR_REPO     = 'my-app'
        IMAGE        = "${ECR_REGISTRY}/${ECR_REPO}:${BUILD_NUMBER}"
    }

    tools {
        'hudson.plugins.sonar.SonarRunnerInstallation' 'SonarScanner'
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/HarshithNA/Project-k8',
                    credentialsId: 'git-credentials'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh "${tool 'SonarScanner'}/bin/sonar-scanner"
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh "docker build -t ${IMAGE} ."
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \
                          docker login --username AWS \
                          --password-stdin ${ECR_REGISTRY}
                        docker push ${IMAGE}
                        docker rmi ${IMAGE}
                    """
                }
            }
        }

        stage('Update Helm & Deploy via ArgoCD') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'git-credentials',
                        usernameVariable: 'GIT_USER',
                        passwordVariable: 'GIT_PASS'
                    ),
                    string(credentialsId: 'argo-server', variable: 'ARGO_SERVER'),
                    string(credentialsId: 'argo-token',  variable: 'ARGO_TOKEN')
                ]) {
                    sh """
                        # Update image tag
                        sed -i 's|tag:.*|tag: "${BUILD_NUMBER}"|' \
                          k8s/helm/values.yaml

                        
                        git config user.email "jenkins@ci.local"
                        git config user.name  "Jenkins"
                        git add k8s/helm/values.yaml
                        git commit -m "ci: update image tag to ${BUILD_NUMBER}"
                        git push https://\${GIT_USER}:\${GIT_PASS}@github.com/HarshithNA/Project-k8 main

                        
                        argocd app sync my-app \
                            --server \${ARGO_SERVER} \
                            --auth-token \${ARGO_TOKEN} \
                            --insecure \
                            --grpc-web

                        
                        argocd app wait my-app \
                            --server \${ARGO_SERVER} \
                            --auth-token \${ARGO_TOKEN} \
                            --insecure \
                            --health \
                            --timeout 120
                    """
                }
            }
        }
    }

    post {
        success {
            echo "✅ Build #${BUILD_NUMBER} deployed successfully"
        }
        failure {
            echo "❌ Build #${BUILD_NUMBER} failed"
        }
        always {
            cleanWs()
        }
    }
}


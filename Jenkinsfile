pipeline {
    agent any

    environment {
        REGISTRY = "localhost:5000"
        IMAGE_NAME = "flask-app"
        IMAGE_TAG = "${env.BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Verify Docker') {
            steps {
                bat 'docker --version'
                bat 'curl -k https://localhost:5000/v2/ || true'
            }
        }

        stage('Build Docker Image') {
            steps {
                bat "docker build -t ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} ."
            }
        }

        stage('Login to Registry') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'registry-creds', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    bat "echo \$PASS | docker login ${REGISTRY} -u \$USER --password-stdin"
                }
            }
        }

        stage('Push to Private Registry') {
            steps {
                bat "docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
            }
        }
    }

    post {
        success {
            echo "Image pushed: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
        }
    }
}

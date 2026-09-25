```groovy
pipeline {
    agent any

    environment {
        REGISTRY = 'localhost:5000'
        IMAGE_NAME = 'flask-app'
        IMAGE_TAG = '6'
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
                bat 'docker info'
            }
        }

        stage('Build Docker Image') {
            steps {
                bat 'docker build -t %REGISTRY%/%IMAGE_NAME%:%IMAGE_TAG% .'
            }
        }

        stage('Login to Registry') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'registry-creds',
                        usernameVariable: 'REGISTRY_USER',
                        passwordVariable: 'REGISTRY_PASSWORD'
                    )
                ]) {
                    bat '''
                        echo %REGISTRY_PASSWORD% | docker login %REGISTRY% -u %REGISTRY_USER% --password-stdin
                    '''
                }
            }
        }

        stage('Push to Private Registry') {
            steps {
                bat 'docker push %REGISTRY%/%IMAGE_NAME%:%IMAGE_TAG%'
            }
        }
    }

    post {
        success {
            echo '========================================'
            echo 'SUCCESS: Docker image pushed successfully!'
            echo '========================================'
        }

        failure {
            echo '========================================'
            echo 'ERROR: Pipeline failed!'
            echo '========================================'
        }
    }
}
```

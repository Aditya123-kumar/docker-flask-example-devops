pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Verify Docker') {
            steps {
                bat 'docker --version'
                bat 'docker compose version'
            }
        }

        stage('Deploy Blue-Green') {
            steps {
                bat 'bash deploy.sh'
            }
        }

        stage('Verify Deployment') {
            steps {
                bat 'docker compose -p flask-prod -f docker-compose.prod.yml ps'
                bat 'type .active_color'
            }
        }
    }

    post {
        success {
            echo 'Zero-downtime deployment completed successfully!'
        }

        failure {
            echo 'Deployment failed!'
        }
    }
}
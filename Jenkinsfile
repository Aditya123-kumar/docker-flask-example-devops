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
        bat 'docker-compose version'
        bat 'curl.exe http://localhost:5000/v2/'
    }
}

stage('Build Docker Image') {
    steps {
        bat 'docker build -t localhost:5000/flask-app:%BUILD_NUMBER% .'
    }
}

stage('Push to Private Registry') {
    steps {
        bat 'docker push localhost:5000/flask-app:%BUILD_NUMBER%'
    }
}

stage('Deploy Blue-Green') {
    steps {
        bat 'powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $env:PATH += \';C:\\Users\\CEREBRENT PC\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin\'; & \'C:\\Program Files\\Git\\bin\\bash.exe\' deploy.sh }"'
    }
}
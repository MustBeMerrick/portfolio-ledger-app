pipeline {
  agent any

  options {
    timeout(time: 20, unit: 'MINUTES')
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Test') {
      steps {
        sh 'swift --version'
        sh 'swift test'
      }
    }
  }
}

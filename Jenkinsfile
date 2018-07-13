pipeline {

    agent any
    options {
         buildDiscarder(logRotator(numToKeepStr: '25'))
         lock resource: 'concurrency_lock'
    }

    environment {
         AWS_REGION = 'us-east-2'
         ENV = "${params.ENV}"
    }

    stages {
        stage('E2E tests') {
            steps {
                withMaven(globalMavenSettingsConfig: 'global-maven-settings') {
                    sh('make test')
                }
            }
            post {
                always {
                    junit 'target/surefire-reports/**/*.xml'
                }
            }
        }
        stage('Generate jar') {
            when {
                allOf {
                    // not a pull request
                    expression { env.CHANGE_ID == null }
                    expression { env.CHANGE_TARGET == null }
                    expression { env.BRANCH_NAME == 'master'}
                }
            }
            steps {
                withMaven(globalMavenSettingsConfig: 'global-maven-settings') {
                    sh('make package')
                }
            }
        }
        stage('Copy Base AMI manifest.json') {
            when {
                allOf {
                    // not a pull request
                    expression { env.CHANGE_ID == null }
                    expression { env.CHANGE_TARGET == null }
                    expression { env.BRANCH_NAME == 'master'}
                }
            }
            steps {
                copyArtifacts filter: 'manifest.json', fingerprintArtifacts: true, projectName: 'Magento-Payments-AMIs/Base-Java-AMI', target: './'
            }
        }
        stage('Bake Service AMI') {
            when {
                allOf {
                    // not a pull request
                    expression { env.CHANGE_ID == null }
                    expression { env.CHANGE_TARGET == null }
                    expression { env.BRANCH_NAME == 'master'}
                }
            }
             environment {
                AMI_ID = sh(script: './ops/ami-packer-templates/ami_extractor.py manifest.json $AWS_REGION', returnStdout: true).trim()
            }
            steps {
                echo "Baking Service AMI from Base AMI with id: $AMI_ID"
                {
                    sh("/usr/local/bin/packer build -force ./ops/ami-packer-templates/jenkins_slave_centos7.json")
                }
                sh('cat manifest.json')
                archiveArtifacts 'manifest.json'
            }
        }
   }

   post {
        failure {
            slackSend channel: '#payments_devops', color: 'danger', message: "${env.JOB_NAME} - ${env.BUILD_DISPLAY_NAME} Failed after ${currentBuild.durationString.replace(' and counting', '')} (<${env.RUN_DISPLAY_URL}|Open>)"
        }

        always {
            script {
                try {
                    sh '''
                        echo "[INFO] Removing .terraform folder"
                        rm -rf ${TF_FOLDER}/.terraform
                       '''
                } catch (exc) {
                    // do nothing - it may be the case that .terraform folder does not exist
                }
            }
        }
    }
}

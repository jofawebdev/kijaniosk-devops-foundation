pipeline {
    agent {
        docker {
            image 'node:18.19.1-alpine3.18'
        }
    }

    options {
        timestamps()
        timeout(time: 10, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    environment {
        CI = 'true'
        PACKAGE_NAME = 'kijanikiosk-payments'
        PACKAGE_VERSION = '1.0.0'
        NEXUS_URL = 'http://172.17.0.1:8081'
        NEXUS_REPOSITORY = 'npm-kijanikiosk'
    }

    stages {
        stage('Lint') {
            steps {
                sh 'npm run lint'
            }
        }

        stage('Build') {
            steps {
                script {
                    env.GIT_SHA = sh(
                        script: 'git rev-parse --short=7 HEAD',
                        returnStdout: true
                    ).trim()
                    env.ARTIFACT_VERSION =
                        "${env.PACKAGE_VERSION}-${env.GIT_SHA}"
                }

                sh '''
                    set -eu
                    npm version "$ARTIFACT_VERSION" --no-git-tag-version
                    npm run build
                    test -s dist/payment.js
                '''
            }
        }

        stage('Verify') {
            parallel {
                stage('Automated Tests') {
                    steps {
                        sh 'npm test'
                    }
                }

                stage('Dependency Security Audit') {
                    steps {
                        sh 'npm audit --audit-level=high'
                    }
                }
            }
        }

        stage('Archive') {
            steps {
                sh 'npm pack'
                archiveArtifacts(
                    artifacts: 'dist/**,package.json,package-lock.json,*.tgz',
                    fingerprint: true
                )
            }
        }

        stage('Publish') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'nexus-npm-credentials',
                        usernameVariable: 'NEXUS_USER',
                        passwordVariable: 'NEXUS_PASSWORD'
                    )
                ]) {
                    sh '''
                        set -eu
                        set +x

                        REGISTRY="${NEXUS_URL}/repository/${NEXUS_REPOSITORY}/"
                        REGISTRY_HOST="${NEXUS_URL#http://}"
                        REGISTRY_HOST="${REGISTRY_HOST#https://}"
                        AUTH="$(printf '%s' "${NEXUS_USER}:${NEXUS_PASSWORD}" \
                            | base64 | tr -d '\\n')"

                        cleanup() {
                            rm -f .npmrc
                        }
                        trap cleanup EXIT

                        printf '//%s/repository/%s/:_auth=%s\\n' \
                            "$REGISTRY_HOST" "$NEXUS_REPOSITORY" "$AUTH" \
                            > .npmrc
                        printf 'always-auth=true\\n' >> .npmrc

                        PACKAGE_TARBALL="$(find . -maxdepth 1 -name '*.tgz' -print -quit)"
                        test -n "$PACKAGE_TARBALL"
                        npm publish "$PACKAGE_TARBALL" \
                            --registry="$REGISTRY" \
                            --ignore-scripts

                        echo "Published version: ${ARTIFACT_VERSION}"
                        echo "Registry: ${REGISTRY}"
                        echo "Expected package endpoint: ${REGISTRY}${PACKAGE_NAME}/-/${PACKAGE_NAME}-${ARTIFACT_VERSION}.tgz"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline succeeded for version ${env.ARTIFACT_VERSION}."
        }
        failure {
            echo 'Pipeline failed. Review the first failing stage and its console output.'
        }
        always {
            echo "Build result: ${currentBuild.currentResult}"
        }
    }
}

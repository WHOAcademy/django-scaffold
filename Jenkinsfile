@Library('openshift-jenkins-shared-libraries')

import platform.*
import util.*

pipeline {
    agent {
        label "master"
    }

    environment {
        // GLobal Vars
        NAME = "django-scaffold"
        PROJECT= "labs"

        // Config repo managed by ArgoCD details
        ARGOCD_CONFIG_REPO = "github.com/mabulgu/ubiquitous-journey.git"
        ARGOCD_CONFIG_REPO_PATH = "example-deployment/values-applications.yaml"
        ARGOCD_CONFIG_REPO_BRANCH = "who"

          // Job name contains the branch eg ds-app-feature%2Fjenkins-123
        JOB_NAME = "${JOB_NAME}".replace("%2F", "-").replace("/", "-")

        GIT_SSL_NO_VERIFY = true

        // Credentials bound in OpenShift
        GIT_CREDS = credentials("${OPENSHIFT_BUILD_NAMESPACE}-git-auth")
        NEXUS_CREDS = credentials("${OPENSHIFT_BUILD_NAMESPACE}-nexus-password")
        ARGOCD_CREDS = credentials("${OPENSHIFT_BUILD_NAMESPACE}-argocd-token")

        // Nexus Artifact repo
        NEXUS_REPO_NAME="labs-static"
        NEXUS_REPO_HELM = "helm-charts"
    }

    // The options directive is for configuration that applies to the whole job.
    options {
        buildDiscarder(logRotator(numToKeepStr: '50', artifactNumToKeepStr: '1'))
        timeout(time: 15, unit: 'MINUTES')
        ansiColor('xterm')
    }

    stages {
        stage('Prepare Environment') {
            failFast true
            parallel {
                stage("Release Build") {
                    options {
                        skipDefaultCheckout(true)
                    }
                    agent {
                        node {
                            label "master"
                        }
                    }
                    when {
                        expression { GIT_BRANCH.startsWith("master") }
                    }
                    steps {
                        script {
                            env.APP_ENV = "prod"
                            // External image push registry info
                            env.IMAGE_REPOSITORY = "quay.io"
                            // app name for master is just learning-experience-platform or something
                            env.APP_NAME = "${NAME}".replace("/", "-").toLowerCase()
                            env.TARGET_NAMESPACE = "${PROJECT}-" + env.APP_ENV
                        }
                    }
                }
                stage("Sandbox Build") {
                    options {
                        skipDefaultCheckout(true)
                    }
                    agent {
                        node {
                            label "master"
                        }
                    }
                    when {
                        expression { GIT_BRANCH.startsWith("dev") || GIT_BRANCH.startsWith("feature") || GIT_BRANCH.startsWith("fix") }
                    }
                    steps {
                        script {
                            env.APP_ENV = "dev"
                            // Sandbox registry deets
                            env.IMAGE_REPOSITORY = 'image-registry.openshift-image-registry.svc:5000'
                            // ammend the name to create 'sandbox' deploys based on current branch
                            env.APP_NAME = "${GIT_BRANCH}-${NAME}".replace("/", "-").toLowerCase()
                            env.TARGET_NAMESPACE = "${PROJECT}-" + env.APP_ENV
                        }
                    }
                }
                stage("Pull Request Build") {
                    options {
                        skipDefaultCheckout(true)
                    }
                    agent {
                        node {
                            label "master"
                        }
                    }
                    when {
                        expression { GIT_BRANCH.startsWith("PR-") }
                    }
                    steps {
                        script {
                            env.APP_ENV = "dev"
                            env.IMAGE_REPOSITORY = 'image-registry.openshift-image-registry.svc:5000'
                            env.APP_NAME = "${GIT_BRANCH}-${NAME}".replace("/", "-").toLowerCase()
                            env.TARGET_NAMESPACE = "${PROJECT}-" + env.APP_ENV
                        }
                    }
                }
            }
        }

          stage("Build (Compile App)") {
            agent {
                node {
                    label "jenkins-slave-python"
                }
            }
            steps {
                script {
                    env.VERSION = sh(returnStdout: true, script: "grep -oP \"(?<=version=')[^']*\" setup.py").trim()
                    env.PACKAGE = "${NAME}-${VERSION}.tar.gz"
                    env.SECRET_KEY = 'xxub4w!i2$*bb#s5r%od4qepb7i-2@pq+yvna-2sj5d!tc8#8f' //TODO: get it from secret
                }
                sh 'printenv'

                echo '### Install deps ###'
                sh 'pip install -r requirements.txt'

                echo '### Running tests ###'
                sh 'python manage.py test blog.tests --testrunner="django_site.testrunners.UnitTestRunner"'

                echo '### Packaging App for Nexus ###'
                sh '''
                    python -m pip install --upgrade pip
                    pip install setuptools wheel
                    python setup.py sdist
                    curl -v -f -u ${NEXUS_CREDS} --upload-file dist/${PACKAGE} http://${SONATYPE_NEXUS_SERVICE_SERVICE_HOST}:${SONATYPE_NEXUS_SERVICE_SERVICE_PORT}/repository/${NEXUS_REPO_NAME}/${APP_NAME}/${PACKAGE}
                '''
            }
            // Post can be used both on individual stages and for the entire build.
            /*post {
                always {
                    // archiveArtifacts "**"
                    junit 'reports/unit/junit.xml'
                    // publish html
                    publishHTML target: [
                        allowMissing: false,
                        alwaysLinkToLastBuild: false,
                        keepAll: true,
                        reportDir: 'reports/coverage/lcov-report',
                        reportFiles: 'index.html',
                        reportName: 'FE Code Coverage'
                    ]
                }
            }*/
        }

      stage("Bake (OpenShift Build)") {
            options {
                skipDefaultCheckout(true)
            }
            agent {
                node {
                    label "master"
                }
            }
            steps {
                /*script {
                    OpenShift.buildAndTag(this, config, env.VERSION, commitId, baseImage, clusterName, environment)
                }*/
                sh 'printenv'

                echo '### Get Binary from Nexus and shove it in a box ###'
                sh  '''
                    rm -rf package-contents*
                    curl -v -f -u ${NEXUS_CREDS} http://${SONATYPE_NEXUS_SERVICE_SERVICE_HOST}:${SONATYPE_NEXUS_SERVICE_SERVICE_PORT}/repository/${NEXUS_REPO_NAME}/${APP_NAME}/${PACKAGE} -o ${PACKAGE}
                    BUILD_ARGS=" --build-arg git_commit=${GIT_COMMIT} --build-arg git_url=${GIT_URL}  --build-arg build_url=${RUN_DISPLAY_URL} --build-arg build_tag=${BUILD_TAG}"
                    echo ${BUILD_ARGS}

                    # oc get bc ${APP_NAME} || rc=$?
                    # dirty hack so i don't have to oc patch the bc for the new version when pushing to quay ...
                    oc delete bc ${APP_NAME} || rc=$?
                    if [[ $TARGET_NAMESPACE == *"dev"* ]]; then
                        echo "🏗 Creating a sandbox build for inside the cluster 🏗"
                        oc new-build --binary --name=${APP_NAME} -l app=${APP_NAME} ${BUILD_ARGS}
                        oc start-build ${APP_NAME} --from-archive=${PACKAGE} ${BUILD_ARGS} --follow
                        # used for internal sandbox build ....
                        oc tag ${OPENSHIFT_BUILD_NAMESPACE}/${APP_NAME}:latest ${TARGET_NAMESPACE}/${APP_NAME}:${VERSION}
                    else
                        echo "🏗 Creating a potential build that could go all the way so pushing externally 🏗"
                        oc new-build --binary --name=${APP_NAME} -l app=${APP_NAME} ${BUILD_ARGS} --push-secret=${QUAY_PUSH_SECRET} --to-docker --to="${IMAGE_REPOSITORY}/${TARGET_NAMESPACE}/${APP_NAME}:${VERSION}"
                        oc start-build ${APP_NAME} --from-archive=${PACKAGE} ${BUILD_ARGS} --follow
                    fi
                '''
            }
      }
/*
        stage("Helm Package App (master)") {

        }

        stage("Deploy App") {

        }

        stage("End to End Test") {

        }

        stage("Promote app to Staging") {

        }*/
    }
}
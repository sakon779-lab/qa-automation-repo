// Olympus-PLRS-Regression — reconstructed from what build #41 actually ran, so switching the job
// to "Pipeline script from SCM" changes WHERE the script lives, not what it does.
//
// ⚠️ THREE THINGS COULD NOT BE READ FROM THE CONSOLE and are marked TODO below: the credentials
// id, the branch each checkout uses, and the build trigger/token. Anonymous API access can start a
// build but not read the job config, so those are the only guesses here — check them against the
// current job before switching it over.
//
// Why the venv lives OUTSIDE the workspace: /var/jenkins_home is a Docker volume, so the
// dependencies (and Playwright's browser binaries, which are large) survive between builds and
// are downloaded exactly once. A workspace-local venv would be wiped and re-fetched every run.

pipeline {
    agent any

    environment {
        VENV_DIR = '/var/jenkins_home/olympus_venv'
        QA_HOST  = 'host.docker.internal'   // the QA stack runs on the host, not in this container
    }

    stages {
        stage('Checkout: Agent Code') {
            steps {
                dir('Olympus-Agents') {
                    // TODO: confirm branch + credentialsId against the existing job
                    git url: 'https://github.com/sakon779-lab/Olympus-Agents.git', branch: 'main'
                }
            }
        }

        stage('Checkout: QA Content (shared repo)') {
            steps {
                dir('qa-content') {
                    git url: 'https://github.com/sakon779-lab/qa-automation-repo.git', branch: 'main'
                }
            }
        }

        stage('Setup Python Environment') {
            steps {
                dir('Olympus-Agents') {
                    sh '''
                        set -e
                        [ ! -d "$VENV_DIR" ] && python3 -m venv "$VENV_DIR"
                        . "$VENV_DIR/bin/activate"

                        # pywin32/pywinpty are Windows-only and torch comes from its own CPU index
                        grep -ivE "pywin32|pywinpty|torch" requirements.txt > requirements_linux.txt
                        pip install -q torch --index-url https://download.pytorch.org/whl/cpu
                        pip install -q --default-timeout=1000 --retries=5 -r requirements_linux.txt
                        pip install -q -r ../qa-content/requirements.txt
                    '''
                }
            }
        }

        stage('Setup Browser Runtime') {
            steps {
                sh '''
                    set -e
                    . "$VENV_DIR/bin/activate"

                    # `rfbrowser init` fetches a node runtime plus browser binaries — hundreds of
                    # megabytes. It lands inside the venv, which is on a persistent volume, so this
                    # runs ONCE and every later build takes the skip. CHROMIUM ONLY: firefox and
                    # webkit would triple the download for browsers no suite asks for.
                    BROWSER_DIR="$(python -c 'import Browser,os;print(os.path.dirname(Browser.__file__))')"
                    if [ -d "$BROWSER_DIR/wrapper/node_modules" ]; then
                        echo "browser runtime already initialised — skipping download"
                    else
                        rfbrowser init chromium
                    fi
                '''
            }
        }

        stage('Run Robot (PLRS / parking_service)') {
            steps {
                dir('qa-content') {
                    sh '''
                        . "$VENV_DIR/bin/activate"
                        robot --outputdir results \
                              --variable BASE_API_URL:http://$QA_HOST:8003 \
                              --variable MOCK_SERVER_URL:http://$QA_HOST:1083 \
                              --variable MOCKSERVER_URL:http://$QA_HOST:1083 \
                              --variable DB_HOST:$QA_HOST \
                              --variable DB_PORT:5438 \
                              --variable DB_NAME:parking \
                              --variable DB_USER:parking \
                              --variable DB_PASS:parking \
                              tests/parking_service/
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'qa-content/results/*', allowEmptyArchive: true
            // Results go to the KB even on failure — a red run is exactly the one worth recording.
            dir('Olympus-Agents') {
                sh '''
                    . "$VENV_DIR/bin/activate"
                    python -m tools.sync_test_results ../qa-content/results/output.xml \
                        --source jenkins --build "$BUILD_NUMBER" --log-url "$BUILD_URL" || true
                '''
            }
        }
    }
}

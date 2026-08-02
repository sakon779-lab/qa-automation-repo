// Olympus-PLRS-Regression.
//
// This is the job's own script, copied out of Jenkins verbatim, with ONE stage added
// (Setup Browser Runtime). Everything else — env, credentials, the `|| true`, the robot
// publisher, the archive patterns — is exactly what the job ran for builds up to #41.

pipeline {
    agent any

    environment {
        NEO4J_URI = 'bolt://host.docker.internal:7687'
        NEO4J_USER = 'neo4j'
        NEO4J_PASSWORD = credentials('neo4j-password')
        DB_HOST = 'host.docker.internal'
        DB_PORT = '5432'
        DB_NAME = 'payment_poc'
        DB_USER = 'postgres'
        DB_PASSWORD = credentials('olympus-db-password')
        OLLAMA_LOCAL_URL = 'http://host.docker.internal:11434'
        PYTHONPATH = "${WORKSPACE}/Olympus-Agents"
    }

    stages {
        stage('Checkout: Agent Code') {
            steps {
                dir('Olympus-Agents') {
                    git branch: 'main',
                        credentialsId: 'github-token',
                        url: 'https://github.com/sakon779-lab/Olympus-Agents.git'
                }
            }
        }

        stage('Checkout: QA Content (shared repo)') {
            steps {
                dir('qa-content') {
                    git branch: 'main',
                        credentialsId: 'github-token',
                        url: 'https://github.com/sakon779-lab/qa-automation-repo.git'
                }
            }
        }

        stage('Setup Python Environment') {
            steps {
                dir('Olympus-Agents') {
                    sh '''
                    VENV_DIR="/var/jenkins_home/olympus_venv"
                    if [ ! -d "$VENV_DIR" ]; then
                        python3 -m venv "$VENV_DIR"
                    fi
                    . "$VENV_DIR/bin/activate"
                    grep -ivE "pywin32|pywinpty|torch" requirements.txt > requirements_linux.txt
                    pip install -q torch --index-url https://download.pytorch.org/whl/cpu
                    pip install -q --default-timeout=1000 --retries=5 -r requirements_linux.txt
                    pip install -q -r ../qa-content/requirements.txt
                    '''
                }
            }
        }

        // The only addition to the original script. `rfbrowser init` fetches a node runtime plus
        // browser binaries — hundreds of megabytes — into the venv, which lives on a persistent
        // volume, so this runs ONCE and every later build takes the skip. Chromium only: firefox
        // and webkit would triple the download for browsers no suite asks for.
        stage('Setup Browser Runtime') {
            steps {
                sh '''
                VENV_DIR="/var/jenkins_home/olympus_venv"
                . "$VENV_DIR/bin/activate"
                BROWSER_DIR="$(python -c 'import Browser,os;print(os.path.dirname(Browser.__file__))' 2>/dev/null)"
                if [ -z "$BROWSER_DIR" ]; then
                    echo "robotframework-browser not installed yet — skipping"
                elif [ -d "$BROWSER_DIR/wrapper/node_modules" ]; then
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
                    // Explicit parking DB vars so this job can NEVER connect to payment's shop_db,
                    // regardless of config defaults. || true = a failing test still syncs its result.
                    sh '''
                    VENV_DIR="/var/jenkins_home/olympus_venv"
                    . "$VENV_DIR/bin/activate"
                    robot --outputdir results \\
                      --variable BASE_API_URL:http://host.docker.internal:8003 \\
                      --variable MOCK_SERVER_URL:http://host.docker.internal:1083 \\
                      --variable MOCKSERVER_URL:http://host.docker.internal:1083 \\
                      --variable DB_HOST:host.docker.internal \\
                      --variable DB_PORT:5438 \\
                      --variable DB_NAME:parking \\
                      --variable DB_USER:parking \\
                      --variable DB_PASS:parking \\
                      tests/parking_service/ || true
                    '''
                }
            }
        }
    }

    post {
        always {
            robot outputPath: 'qa-content/results', passThreshold: 100.0, unstableThreshold: 0.0
            archiveArtifacts artifacts: 'qa-content/results/*.xml,qa-content/results/*.html', allowEmptyArchive: true
            dir('Olympus-Agents') {
                sh '''
                VENV_DIR="/var/jenkins_home/olympus_venv"
                . "$VENV_DIR/bin/activate"
                python -m tools.sync_test_results ../qa-content/results/output.xml \\
                    --source jenkins --build $BUILD_NUMBER --log-url $BUILD_URL \\
                    || echo "WARNING: test result sync failed"
                '''
            }
        }
    }
}

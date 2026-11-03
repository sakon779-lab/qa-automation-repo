// Playwright regression for one project's suite — the Playwright twin of ../Jenkinsfile (Robot/PLRS).
//
// One file for every Playwright project: the job passes SERVICE (the folder under tests/ that
// holds a playwright.config.ts). What a person gets is the same as the Robot job:
//   - Jenkins's test-results page (JUnit) — per-test pass/fail, history, trend, "Rebuild"
//   - the raw reports archived with the build
//   - the run pushed into the knowledge graph (TestRun → TestCase.last_status) for Apollo
// Re-running is the job's Build button: no agent, no tokens.

pipeline {
    agent any

    parameters {
        string(name: 'SERVICE', defaultValue: 'node_demo',
               description: 'folder under tests/ with a playwright.config.ts (node_demo = ONODE)')
    }

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
        // the QA stack runs on the Docker host; the config builds every address from this
        QA_HOST = 'host.docker.internal'
    }

    stages {
        stage('Checkout: Agent Code') {
            steps {
                dir('Olympus-Agents') {
                    git branch: 'main', credentialsId: 'github-token',
                        url: 'https://github.com/sakon779-lab/Olympus-Agents.git'
                }
            }
        }

        stage('Checkout: QA Content (shared repo)') {
            steps {
                dir('qa-content') {
                    git branch: 'main', credentialsId: 'github-token',
                        url: 'https://github.com/sakon779-lab/qa-automation-repo.git'
                }
            }
        }

        stage('Install Playwright') {
            steps {
                dir('qa-content') {
                    // API suites launch no browser, so no `playwright install` — only the npm deps
                    sh 'npm ci --no-audit --no-fund'
                }
            }
        }

        stage('Run Playwright') {
            steps {
                dir('qa-content') {
                    // || true: a red test still publishes and syncs its result — the verdict is
                    // the deliverable, and the JUnit publisher marks the build UNSTABLE for it
                    sh '''
                    rm -rf results/playwright && mkdir -p results/playwright
                    npx playwright test --config "tests/${SERVICE}/playwright.config.ts" || true
                    if [ ! -f "results/playwright/${SERVICE}-junit.xml" ]; then
                        echo "❌ no results/playwright/${SERVICE}-junit.xml — the suite did not run"
                        exit 1
                    fi
                    '''
                }
            }
        }
    }

    post {
        always {
            junit testResults: "qa-content/results/playwright/${params.SERVICE}-junit.xml",
                  allowEmptyResults: false
            archiveArtifacts artifacts: 'qa-content/results/playwright/**', allowEmptyArchive: true
            dir('Olympus-Agents') {
                sh '''
                VENV_DIR="/var/jenkins_home/olympus_venv"
                . "$VENV_DIR/bin/activate"
                python -m tools.sync_test_results "../qa-content/results/playwright/${SERVICE}.json" \\
                    --source jenkins-${SERVICE} --build $BUILD_NUMBER --log-url $BUILD_URL \\
                    || echo "WARNING: test result sync failed"
                '''
            }
        }
    }
}

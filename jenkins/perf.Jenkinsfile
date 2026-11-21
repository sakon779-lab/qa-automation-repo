// Performance regression for one project — every card's k6 script on main, re-measured.
//
// Artemis runs a card's k6 script once, in that card's round. This job runs ALL of them again,
// nightly, so a later card that makes an endpoint slower (and declares no budget of its own) is
// caught by the budgets earlier cards set. The perf twin of playwright.Jenkinsfile.
//
// Why on the HOST node (label olympus-host), not in the controller's container like the functional
// job: a load test measured through Docker's network measures the network too, and the run must
// hold the same machine-wide lock Artemis's run_k6 holds (no functional gate or red team runs
// during a measurement). The host node runs in the Olympus checkout (OLYMPUS_HOME) with its own
// k6, .env and venv — `python -m tools.run_perf` there does the work:
//   - the card's contract budgets, checked against the script before it runs (never loosened)
//   - the project's perf stack (environments.perf in .olympus/project.json)
//   - every run kept: logs/perf/runs.jsonl, Postgres perf_runs (Grafana), the KB (Apollo)
//   - JUnit: one test per budget threshold, failed when crossed or when it measured nothing
// Exit codes: 0 every budget held · 3 a budget crossed (UNSTABLE via JUnit) · 2 could not measure.

pipeline {
    agent { label 'olympus-host' }

    parameters {
        string(name: 'PROJECT', defaultValue: 'ONODE', description: 'Jira project key the scripts belong to')
        string(name: 'SERVICE', defaultValue: 'node_demo',
               description: 'folder under tests/ whose perf/ holds the k6 scripts (node_demo = ONODE)')
    }

    options {
        timestamps()
        timeout(time: 90, unit: 'MINUTES')    // the exclusive lock alone may wait 30
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout: QA Content') {
            steps {
                checkout scm
            }
        }

        stage('Run k6 budgets') {
            steps {
                script {
                    def rc = bat(returnStatus: true, script: '''@echo off
chcp 65001 >nul
if not defined OLYMPUS_HOME (
  echo OLYMPUS_HOME is not set: start this node with "python -m tools.jenkins_agent start" from the Olympus checkout
  exit /b 2
)
set PYTHONUTF8=1
set PYTHONIOENCODING=utf-8
if exist "%WORKSPACE%\\results\\perf" rmdir /s /q "%WORKSPACE%\\results\\perf"
cd /d "%OLYMPUS_HOME%"
".venv\\Scripts\\python.exe" -m tools.run_perf %PROJECT% --qa-dir "%WORKSPACE%" --service %SERVICE% ^
  --junit "%WORKSPACE%\\results\\perf\\junit.xml" --source jenkins-perf-%BUILD_NUMBER%
''')
                    if (rc == 2) {
                        error("run_perf could not measure (exit 2) — see the log: no script, no perf target, k6 missing, or the lock was not had")
                    }
                    if (rc != 0 && rc != 3) {
                        error("run_perf exited ${rc}")
                    }
                }
            }
        }
    }

    post {
        always {
            junit testResults: 'results/perf/junit.xml', allowEmptyResults: true
            archiveArtifacts artifacts: 'results/perf/**', allowEmptyArchive: true
        }
    }
}

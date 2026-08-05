// Olympus-PLRS-Regression.
//
// This is the job's own script, copied out of Jenkins verbatim, with ONE stage added
// (Setup Browser Runtime). Everything else — env, credentials, the `|| true`, the robot
// publisher, the archive patterns — is exactly what the job ran for builds up to #41.

pipeline {
    agent any

    parameters {
        // How many pabot workers the parallel lane gets, and the escape hatch: 1 turns the run
        // fully sequential without editing this file.
        //
        // 8 is measured, not guessed — and the measurement is the reason it is not 4:
        //
        //   #68  sequential   457 tests in 63.5s
        //   #69  pabot x4     457 tests in 69.1s   SLOWER than sequential
        //   #70  pabot x8     457 tests in 42.5s
        //
        // Each suite runs as its own process, so it pays robot startup plus the library imports
        // (Requests, Database, Browser) every time. Across 44 suites that inflates 63.5s of real
        // work to 265s at x4 and 328s at x8 — a fixed cost per suite that parallelism divides.
        // Four workers do not divide it enough to win; eight do. Note the total work went UP from
        // x4 to x8 (more contention on one app and one DB) while wall time still dropped, which
        // says the ceiling is not here yet — worth re-measuring if the suite count grows.
        string(name: 'PARALLEL_PROCESSES', defaultValue: '8',
               description: 'pabot workers for the parallel lane (1 = sequential). 8 measured best.')
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

        // The only addition to the original script, and it can NEVER fail the build.
        //
        // `rfbrowser init` needs npm, and this Jenkins image has no Node — build #45 died on
        // "FileNotFoundError: 'npm'" and took a working pipeline down with it, in exchange for a
        // capability no suite uses yet. Until a browser suite actually exists, a missing runtime
        // is a fact to report, not a reason to fail: the API tests are what this job is for.
        //
        // When browser tests do arrive, install Node in the Jenkins image and this stage starts
        // working with no change here. The download (node modules + chromium, hundreds of MB)
        // lands in the venv on a persistent volume, so it happens once and later builds skip it.
        // Chromium only — firefox and webkit would triple it for browsers nothing asks for.
        stage('Setup Browser Runtime') {
            steps {
                sh '''
                VENV_DIR="/var/jenkins_home/olympus_venv"
                . "$VENV_DIR/bin/activate"
                BROWSER_DIR="$(python -c 'import Browser,os;print(os.path.dirname(Browser.__file__))' 2>/dev/null || true)"
                if [ -z "$BROWSER_DIR" ]; then
                    echo "ℹ️  robotframework-browser not installed — browser tests cannot run"
                elif [ -d "$BROWSER_DIR/wrapper/node_modules/playwright-core/.local-browsers" ]; then
                    # .local-browsers only exists once chromium has actually been DOWNLOADED.
                    # The previous check looked at wrapper/node_modules, which ships inside the pip
                    # package and is therefore always present — so this stage reported "already
                    # initialised" on every build and `rfbrowser init` never ran once. The same
                    # trap caught the dev machine: node_modules there, no browser, and Playwright
                    # only says so when a test tries to open a page.
                    echo "✅ browser runtime already initialised — skipping download"
                elif ! command -v npm >/dev/null 2>&1; then
                    echo "⚠️  no npm in this image — SKIPPING browser runtime."
                    echo "    Browser-level suites will not run until Node is installed here."
                    echo "    Every API suite is unaffected; this is not a build failure."
                else
                    rfbrowser init chromium || echo "⚠️  rfbrowser init failed — browser suites will not run"
                fi
                '''
            }
        }

        // TWO LANES, ONE REPORT.
        //
        // Most suites are isolation-safe by construction: a six-digit <dynamic_id> per test, each
        // suite seeding its own chain, surgical DELETE teardown (no TRUNCATE anywhere in the repo)
        // and MockServer expectations scoped by a per-test X-Request-Id. Those run under pabot.
        //
        // Two are not, and no assertion can make them safe — the hazard is in the endpoint, not
        // the test. POST /bookings/sweep-noshows (PLRS-21) marks every eligible row in the whole
        // database, and PLRS-59 TC-005 has to arm the stub with request_id=ANY because the app
        // mints the id itself, so it would answer any other suite's call to /charge. Both carry
        // `Force Tags  serial` with the reason written where the hazard lives.
        //
        // Serial lane runs FIRST and alone — running it after would leave it racing whatever
        // pabot still had in flight, which is the thing being avoided. rebot then merges the two
        // outputs into results/output.xml, so the publisher below, the pass count and the result
        // sync all see exactly what they saw when this was a single robot run.
        //
        // PARALLEL_PROCESSES is a job parameter (default 8, measured — see the parameters block):
        // one number to turn down if the QA stack or the DB starts complaining, without touching
        // this file.
        stage('Run Robot (PLRS / parking_service)') {
            steps {
                dir('qa-content') {
                    // Explicit parking DB vars so this job can NEVER connect to payment's shop_db,
                    // regardless of config defaults. || true = a failing test still syncs its result.
                    sh '''
                    VENV_DIR="/var/jenkins_home/olympus_venv"
                    . "$VENV_DIR/bin/activate"
                    # The :-8 matters on its own: a build triggered before Jenkins has registered
                    # the parameter (the first run after this block changes) passes nothing, and
                    # the shell default is what decides the run. Keep it equal to defaultValue.
                    PROCS="${PARALLEL_PROCESSES:-8}"

                    ROBOT_VARS="--variable BASE_API_URL:http://host.docker.internal:8003 \\
                      --variable MOCK_SERVER_URL:http://host.docker.internal:1083 \\
                      --variable MOCKSERVER_URL:http://host.docker.internal:1083 \\
                      --variable DB_HOST:host.docker.internal \\
                      --variable DB_PORT:5438 \\
                      --variable DB_NAME:parking \\
                      --variable DB_USER:parking \\
                      --variable DB_PASS:parking"

                    rm -rf results && mkdir -p results

                    echo "── serial lane (suites tagged 'serial', nothing else running) ──"
                    robot --outputdir results/serial --output output.xml \\
                      --include serial $ROBOT_VARS \\
                      tests/parking_service/ || true

                    echo "── parallel lane ($PROCS processes) ──"
                    if command -v pabot >/dev/null 2>&1; then
                        pabot --processes "$PROCS" \\
                          --outputdir results/parallel --output output.xml \\
                          --exclude serial $ROBOT_VARS \\
                          tests/parking_service/ || true
                    else
                        # pabot missing is a reason to be slow, not a reason to report nothing.
                        echo "⚠️  pabot not installed — running the parallel lane sequentially"
                        robot --outputdir results/parallel --output output.xml \\
                          --exclude serial $ROBOT_VARS \\
                          tests/parking_service/ || true
                    fi

                    echo "── merging both lanes into results/output.xml ──"
                    rebot --outputdir results --output output.xml \\
                      --log log.html --report report.html \\
                      results/serial/output.xml results/parallel/output.xml || true

                    # A merge that silently produced nothing would look like a clean run with zero
                    # tests, which the publisher would happily accept. Say so instead.
                    if [ ! -f results/output.xml ]; then
                        echo "❌ rebot produced no results/output.xml — the two lanes did not merge"
                        exit 1
                    fi
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

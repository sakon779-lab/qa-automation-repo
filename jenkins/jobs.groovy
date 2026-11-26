// Olympus regression jobs, as code (Job DSL) — read by the seed job `Olympus-Seed-Jobs`.
//
// A job is created or changed by a PR to this file: reviewed, merged, and the seed job (which
// polls main) applies it. No one — person or agent — needs Jenkins admin rights or a Jenkins
// token to add a project's regression, and a fresh Jenkins rebuilds every job from here.
//
// Olympus-PLRS-Regression was removed on 15 Nov 2026: PLRS is no longer developed and its QA stack
// is shut down (disabled since 4 Nov). Its Robot script, ./Jenkinsfile, stays for the next Robot
// project. A job removed here is NOT deleted by the seed job (removedJobAction = ignore), so a
// person deletes it in Jenkins after the merge.
//
// One entry per job. `script` is the stack's Jenkinsfile (Jenkinsfile = Robot,
// jenkins/playwright.Jenkinsfile = Playwright, jenkins/perf.Jenkinsfile = the k6 budgets, which runs
// on the Olympus host node); `cron` the timer (default nightly at 5); `params` the build parameters, each
// with the default a timer or a remote trigger runs with. `token` is the job's "Trigger builds
// remotely" token — not a secret credential, it only queues that one job on this Jenkins
// (Olympus's tools/trigger_jenkins uses it).

def projects = [
    [name       : 'Olympus-ONODE-Regression',
     description: 'ONODE Playwright suite (tests/node_demo) against onode_qa (:8006, Postgres :5442, ' +
                  'MockServer :1087); results pushed into the Apollo KB.',
     script     : 'jenkins/playwright.Jenkinsfile',
     params     : [SERVICE: ['node_demo', 'folder under tests/ with the suite\'s config']],
     token      : 'onode-trigger-4c1e'],
    // every card's k6 script (tests/node_demo/perf/*.k6.js) re-measured against the perf stack, on
    // the Olympus host node — jenkins/perf.Jenkinsfile says why it is not in the container
    [name       : 'Olympus-ONODE-Perf',
     description: 'ONODE performance budgets: every card\'s k6 script on main, re-measured against ' +
                  'onode_perf (:8026) on the Olympus host node; each run kept in Postgres perf_runs ' +
                  '(Grafana: Performance Budgets) and the Apollo KB.',
     script     : 'jenkins/perf.Jenkinsfile',
     params     : [PROJECT: ['ONODE', 'Jira project key the scripts belong to'],
                   SERVICE: ['node_demo', 'folder under tests/ whose perf/ holds the k6 scripts'],
                   PROFILE: ['nightly', 'budget,stress,load — the budgets, the capacity, and 80% of the approved capacity']],
     cron       : 'H 3 * * *',       // after the security nightly (2), before the functional one (5)
     token      : 'onode-perf-trigger-7d2a'],
    // the long load profiles, once a week: endurance (50% of the approved capacity for 30 min per
    // endpoint, judged on drift) and spike (150%, judged on recovery). Sunday just after midnight, so
    // its hour-plus hold of the machine meets neither the security nightly (2) nor the perf one (3).
    [name       : 'Olympus-ONODE-Perf-Weekly',
     description: 'ONODE endurance + spike: every card\'s k6 script driven at a share of the capacity a ' +
                  'person approved (python -m tools.perf_baseline), on the Olympus host node; kept in ' +
                  'Postgres perf_runs (Grafana: Performance Budgets) and the Apollo KB.',
     script     : 'jenkins/perf.Jenkinsfile',
     params     : [PROJECT: ['ONODE', 'Jira project key the scripts belong to'],
                   SERVICE: ['node_demo', 'folder under tests/ whose perf/ holds the k6 scripts'],
                   PROFILE: ['weekly', 'endurance,spike']],
     cron       : 'H 0 * * 0',
     token      : 'onode-perf-weekly-trigger-3b9e'],
]

projects.each { p ->
    pipelineJob(p.name) {
        description(p.description + ' Defined in jenkins/jobs.groovy — change it there, not here.')
        parameters {
            p.params.each { name, spec -> stringParam(name, spec[0], spec[1]) }
        }
        properties {
            pipelineTriggers {
                triggers {
                    cron { spec(p.cron ?: 'H 5 * * *') }     // nightly
                }
            }
        }
        authenticationToken(p.token)
        disabled(p.disabled ?: false)
        definition {
            cpsScm {
                scm {
                    git {
                        remote {
                            url('https://github.com/sakon779-lab/qa-automation-repo.git')
                            credentials('github-token')
                        }
                        branch('*/main')
                    }
                }
                scriptPath(p.script)
                lightweight(true)
            }
        }
    }
}

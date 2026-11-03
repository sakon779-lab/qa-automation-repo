// Olympus regression jobs, as code (Job DSL) — read by the seed job `Olympus-Seed-Jobs`.
//
// A job is created or changed by a PR to this file: reviewed, merged, and the seed job (which
// polls main) applies it. No one — person or agent — needs Jenkins admin rights or a Jenkins
// token to add a project's regression, and a fresh Jenkins rebuilds every job from here.
//
// One entry per project. `script` is the stack's Jenkinsfile (jenkins/<stack>.Jenkinsfile);
// `service` is the folder under tests/ the suite lives in. `token` is the job's "Trigger builds
// remotely" token — not a secret credential, it only queues that one job on this Jenkins
// (Olympus's tools/trigger_jenkins uses it).
//
// Olympus-PLRS-Regression (Robot, ../Jenkinsfile) predates this file and is still configured by
// hand; it moves here once ONODE has run from it for a while.

def projects = [
    [name       : 'Olympus-ONODE-Regression',
     description: 'ONODE Playwright suite (tests/node_demo) against onode_qa (:8006, Postgres :5442, ' +
                  'MockServer :1087); results pushed into the Apollo KB.',
     script     : 'jenkins/playwright.Jenkinsfile',
     service    : 'node_demo',
     token      : 'onode-trigger-4c1e'],
]

projects.each { p ->
    pipelineJob(p.name) {
        description(p.description + ' Defined in jenkins/jobs.groovy — change it there, not here.')
        parameters {
            stringParam('SERVICE', p.service, 'folder under tests/ with the suite\'s config')
        }
        properties {
            pipelineTriggers {
                triggers {
                    cron { spec('H 5 * * *') }     // nightly, like the PLRS job
                }
            }
        }
        authenticationToken(p.token)
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

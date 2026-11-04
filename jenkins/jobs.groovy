// Olympus regression jobs, as code (Job DSL) — read by the seed job `Olympus-Seed-Jobs`.
//
// A job is created or changed by a PR to this file: reviewed, merged, and the seed job (which
// polls main) applies it. No one — person or agent — needs Jenkins admin rights or a Jenkins
// token to add a project's regression, and a fresh Jenkins rebuilds every job from here.
//
// One entry per project. `script` is the stack's Jenkinsfile (Jenkinsfile = Robot,
// jenkins/playwright.Jenkinsfile = Playwright); `params` are the job's build parameters, each
// with the default a timer or a remote trigger runs with. `token` is the job's "Trigger builds
// remotely" token — not a secret credential, it only queues that one job on this Jenkins
// (Olympus's tools/trigger_jenkins uses it).

def projects = [
    [name       : 'Olympus-PLRS-Regression',
     description: 'Run the PLRS suite (tests/parking_service) from the shared QA repo against plrs_qa ' +
                  '(:8003, parking db) and push results into Apollo KB.',
     script     : 'Jenkinsfile',
     params     : [PARALLEL_PROCESSES: ['8', 'pabot workers for the parallel lane (1 = sequential). 8 measured best.']],
     token      : 'plrs-trigger-7f3a',
     // PLRS is no longer developed and its QA stack (plrs_qa :8003) is shut down to save the
     // machine (4 Nov 2026): every nightly run would fail on connection errors. Disabled, not
     // deleted — the build history stays and `false` brings it back.
     disabled   : true],
    [name       : 'Olympus-ONODE-Regression',
     description: 'ONODE Playwright suite (tests/node_demo) against onode_qa (:8006, Postgres :5442, ' +
                  'MockServer :1087); results pushed into the Apollo KB.',
     script     : 'jenkins/playwright.Jenkinsfile',
     params     : [SERVICE: ['node_demo', 'folder under tests/ with the suite\'s config']],
     token      : 'onode-trigger-4c1e'],
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
                    cron { spec('H 5 * * *') }     // nightly
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

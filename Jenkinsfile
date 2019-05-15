#!groovy

pipeline
{
  agent none

  parameters {
    booleanParam(defaultValue: false, description: 'Is the pull request approved for testing?', name: 'TRUST_BUILD')
  }

  stages {

    stage ("info")
    {
      steps
      {
        echo "PR: ${env.CHANGE_ID} - ${env.CHANGE_TITLE}"
        echo "CHANGE_AUTHOR_EMAIL: ${env.CHANGE_AUTHOR_EMAIL}"
        echo "building on node ${env.NODE_NAME}"
      }
    }

    stage ("Check permissions")
    {
      when {
        allOf {
            environment name: 'TRUST_BUILD', value: 'false' 
            not {branch 'master'}
            not {changeRequest authorEmail: "heister@clemson.edu"}
            not {changeRequest authorEmail: "koecher@hsu-hamburg.de"}
	    }	    
      }
      steps {
          echo "Please ask an admin to rerun jenkins with TRUST_BUILD=true"
            sh "exit 1"
      }
    }

    stage ("min-ubuntu16")
    {
      options {timeout(time: 240, unit: 'MINUTES')}
      agent
      {
        dockerfile {
          dir '.ci'
          filename 'dockerfile.ubuntu16'
        }
      }
      steps
      {
        sh '''
        lsb_release -a
        echo $WORKSPACE
        ./candi.sh -j 4 --packages="dealii"
        cp ~/deal.ii-candi/tmp/build/deal.II-*/detailed.log .
        '''

	archiveArtifacts artifacts: 'detailed.log', fingerprint: true

        sh '''
        cd ~/deal.ii-candi/tmp/build/deal.II-* && make test
        '''
      }
    }

    stage ("default-ubuntu16")
    {
      options {timeout(time: 480, unit: 'MINUTES')}
      agent
      {
        dockerfile {
          dir '.ci'
          filename 'dockerfile.ubuntu16'
        }
      }
      steps
      {
        sh '''
        lsb_release -a
        echo $WORKSPACE
        ./candi.sh -j 4
        cp ~/deal.ii-candi/tmp/build/deal.II-*/detailed.log .
        '''

	archiveArtifacts artifacts: 'detailed.log', fingerprint: true

        sh '''
        cd ~/deal.ii-candi/tmp/build/deal.II-* && make test
        '''
      }
    }

    stage ("cmake-ubuntu16")
    {
      options {timeout(time: 60, unit: 'MINUTES')}
      agent
      {
        dockerfile {
          dir '.ci'
          filename 'dockerfile.ubuntu16'
        }
      }
      steps
      {
        sh '''
        lsb_release -a
        echo $WORKSPACE
        ./candi.sh -j 4 --packages="cmake"
        . ~/deal.ii-candi/configuration/enable.sh
        which cmake
        cmake --version
        '''
      }
    }

  }


}

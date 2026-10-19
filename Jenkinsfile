#!groovy

pipeline
{
  agent none

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
            changeRequest()
            not {changeRequest authorEmail: "timo.heister@gmail.com"}
	    }
      }
      agent
      {
        dockerfile
        {
          dir 'contrib/ubuntu2404'
        }
      }
      steps {
        sh '''
        wget -q -O - https://api.github.com/repos/dealii/candi/issues/${CHANGE_ID}/labels | grep 'ready to test' || \
        { echo "This commit will only be tested when it has the label 'ready to test'. Trigger a rebuild by adding a comment that contains '/rebuild'..."; exit 1; }
        '''

      }
    }

    stage ("Ubuntu-20.04")
    {
      options {timeout(time: 600, unit: 'MINUTES')}
      agent
      {
        dockerfile
        {
          dir 'contrib/ubuntu2004'
        }
      }

      steps
      {
        sh '''#!/bin/bash
	set -e
	set -x
	mpicxx -v
	cmake --version
	# Ubuntu 20.04 only ships cmake 3.16 not 3.23:
	echo 'PACKAGES="once:cmake ${PACKAGES}"' > local.cfg
	echo 'DEAL_II_CONFOPTS="-D CMAKE_BUILD_TYPE=Debug"' >> local.cfg
	rm -rf /install
        ./candi.sh -j 8 -p /install
        cp /install/tmp/build/deal.II-*/detailed.log detailed-ubuntu2004.log
        '''
	archiveArtifacts artifacts: 'detailed-ubuntu2004.log', fingerprint: true

        sh '''#!/bin/bash
        cd /install/tmp/build/deal.II-* && \
          OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 make test
        '''
      }
    }

    stage ("Ubuntu-24.04")
    {
      options {timeout(time: 600, unit: 'MINUTES')}
      agent
      {
        dockerfile
        {
          dir 'contrib/ubuntu2404'
        }
      }

      steps
      {
        sh '''#!/bin/bash
	set -e
	set -x
	mpicxx -v
	cmake --version
	echo 'DEAL_II_CONFOPTS="-D CMAKE_BUILD_TYPE=Debug"' > local.cfg
	rm -rf /install/
        ./candi.sh -j 8 -p /install
        cp /install/tmp/build/deal.II-*/detailed.log detailed-ubuntu2404.log
        '''
	archiveArtifacts artifacts: 'detailed-ubuntu2404.log', fingerprint: true

        sh '''#!/bin/bash
        cd /install/tmp/build/deal.II-* && \
          OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 make test
        '''
      }
    }

    stage ("OSX-ARM")
    {
      options {timeout(time: 600, unit: 'MINUTES')}
      agent
      {
         node
        {
          label 'osx'
        }
      }

      post { cleanup { cleanWs() } }

      steps
      {
        sh '''#!/bin/bash
	set -e
	set -x
	echo 'DEAL_II_CONFOPTS="-D CMAKE_BUILD_TYPE=Debug"' > local.cfg
        ./candi.sh -j 8 --packages="p4est petsc trilinos sundials dealii" -p $WORKSPACE
        cp $WORKSPACE/tmp/build/deal.II-*/detailed.log detailed-osx.log
        '''

	archiveArtifacts artifacts: 'detailed-osx.log', fingerprint: true

        sh '''#!/bin/bash
        cd $WORKSPACE/tmp/build/deal.II-* && ctest -j 4 --output-on-failure
        '''
      }
    }

  }
}

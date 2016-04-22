candi (Compile &amp; Install)
=====

This shell script downloads, configures, builds, and installs deal.II with common dependencies on linux-based systems.

Quickstart
----

The following commands download the current version of the installer and then installs
the latest deal.II release and common dependencies:

```bash
 git clone https://github.com/dealii/candi
 cd candi
 ./candi.sh -j2
```

Follow the instructions on the screen (you can abort the process by pressing < CTRL > + C)

### Examples

#### Install deal.II on RHEL 7, CentOS 7 or Fedora 21/22:
```bash
  module load mpi/openmpi-`uname -i`
  export CC=mpicc; export CXX=mpicxx; export FC=mpif90; export FF=mpif77
  ./candi.sh
```

#### Install deal.II on ubuntu 12.04, 14.xx, 15.xx:
```bash
  export CC=mpicc; export CXX=mpicxx; export FC=mpif90; export FF=mpif77
  ./candi.sh
```

#### Install deal.II on a generic Linux cluster:
```bash
  export CC=mpicc, export CXX=mpicxx; export FC=mpif90; export FF=mpif77
  ./candi.sh --platform=./deal.II-toolchain/platforms/supported/linux_cluster.platform
```
Note that you probably also want to change the prefix path (see below) and 
the path to BLAS and LAPACK in the configuration file (see below).

Adapting candi to your needs
----

### Command line options

You can get a list of all options by running ``./candi.sh -h``

You can combine the command line options given below.

#### Prefix path: `[-p=<PATH>]`, `[--prefix=<PATH>]`
```bash
  ./candi.sh --prefix=Your/Prefix/Path
```

#### Multiple build processes: `[-j <N>]`, `[-j<N>]`, `[--PROCS=<N>]`
```bash
  ./candi.sh -j <N>
```

* Example: to use 2 build processes type `./candi.sh -j2`.
* Be careful with this option! You need to have enough system memory (e.g. at least 8GB for 2 or more processes).

### Configuration file options

Edit the configuration file behind the file "candi.cfg", e.g.
```bash
  gedit candi.cfg
```

You can adapt several things to your personal needs here
* the `DOWNLOAD_PATH` folder (can be safely removed after installation),
* the `UNPACK_PATH` folder of the downloaded packages (can be safely removed after installation),
* the `BUILD_PATH` folder (can be safely removed after installation),
* the `INSTALL_PATH` destination folder,

and more options.

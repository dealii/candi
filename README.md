candi (Compile &amp; Install)
=====

* Downloads, configures, builds and install deal.II

General
----

* candi is a bash script based installer tool.
* candi is preconfigured to install a working deal.II toolchain on tested platforms
* Open a Terminal.
* Commands for your terminal are further denoted with the prefix "$>"
* Do NOT copy the prefix "$>" into your terminal!

Download
----

```bash
 $> git clone https://github.com/koecher/candi
```
This downloads the current version of candi.

Usage (for installing deal.II)
----

### First Run
Make sure, that you are in the downloaded folder of candi; e.g. after the download type in
```bash
 $> cd candi
```
Note: candi is preconfigured to compile and install the current version of the deal.II library.

You run the installer by
```bash
 $> ./candi.sh
```
* Abort the installer by pressing < CTRL > + C

### deal.II Library with Trilinos, PetSc, MPI Support, and more:
* Make sure that you have done the First Run steps from above.
* Abort the installer by pressing < CTRL > + C
* READ CAREFULLY the instructions!
* INSTALL the needed packages from your distribution. (You need super user rights for this step.)
* SET UP the intended compilers; cf. the following instructions for this step.

#### Install deal.II on RHEL 7, CentOS 7 or Fedora 21/22:
```bash
  $> module load mpi/openmpi-`uname -i`
  $> export CC=mpicc; export CXX=mpicxx; export FC=mpif90; export FF=mpif77
  $> ./candi.sh
```
Hit return and wait.

#### Install deal.II on ubuntu 12.04, 14.xx, 15.xx:
```bash
  $> export CC=mpicc; export CXX=mpicxx; export FC=mpif90; export FF=mpif77
  $> ./candi.sh
```
Hit return and wait.

#### Install deal.II on a generic Linux cluster:
```bash
  $> export CC=mpicc, export CXX=mpicxx; export FC=mpif90; export FF=mpif77
  $> ./candi.sh --platform=./deal.II-toolchain/platforms/supported/linux_cluster.platform
```
Hit return and wait.
Note that you probably also want to change the prefix path (see below) and 
the path to BLAS and LAPACK in the configuration file (see below).

Adapting candi to your needs
----

### Command line options (CLO) for `./candi.sh [CLO]`

* You can combine the command line options given below.
* Read carefully the output of `./candi.sh` before running!

#### CLO: Prefix path: `[-p=<PATH>]`, `[--prefix=<PATH>]`
```bash
  $> ./candi.sh --prefix=Your/Prefix/Path
```

#### CLO: Multiple build processes: `[-j <N>]`, `[-j<N>]`, `[--PROCS=<N>]`
```bash
  $> ./candi.sh -j <N>
```

* Example: to use 2 build processes type `./candi.sh -j2`.
* Be careful with this option! You need to have enough system memory (e.g. at least 8GB for 2 or more processes).

### Configuration file options (CFO)

Edit the configuration file behind the softlink "candi.cfg", e.g.
```bash
  $> gedit candi.cfg
```

You can adapt several things to your personal needs here
* the `DOWNLOAD_PATH` folder (can be safely removed after installation),
* the `UNPACK_PATH` folder of the downloaded packages (can be safely removed after installation),
* the `BUILD_PATH` folder (can be safely removed after installation),
* the `INSTALL_PATH` destination folder,

and more options.

Remarks. Please set the variables
* `PREFIX_PATH`
* `PROCS`

via the command line options (CLO) as described above.

Note: setting the denoted variables in the configuration file will fix them,
and they cannot be overwritten by command line options anymore.

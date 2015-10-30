candi
=====

candi - (Compile &amp; Install) - Downloads, configures, builds and install various FEM libraries, e.g. deal.II, FEniCS

General
----

* candi is a bash script based installer tool.
* Open a Terminal.
* Commands are further denoted with the prefix "$>"
* Do NOT copy the prefix "$>" into your terminal!

Download
----

```bash
 $> git clone https://github.com/koecher/candi
```
This downloads the current version of candi.

Usage
----

### First Run
Make sure, that you are in the downloaded folder of candi; e.g. after the download type in
```bash
 $> cd candi
```
Note: candi is initially configured to compile and install the current version of the deal.II library.

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

#### Install deal.II on RHEL 7, CentOS 7 or Fedora 20/21:
```bash
  $> module load mpi/openmpi-`uname -i`
  $> export CC=mpicc; export CXX=mpicxx; export FC=mpif90; export FF=mpif77
  $> ./candi.sh
```
Hit return and wait.

#### Install deal.II on ubuntu 12.04, 14.xx, 15.xx :
```bash
  $> export CC=mpicc; export CXX=mpicxx; export FC=mpif90; export FF=mpif77
  $> ./candi.sh
```
Hit return and wait.

Adapting candi to your needs
----

### Command line options (CLO) for `./candi.sh [CLO]`

You can combine the command line options given below.
Read carefully the output of `./candi.sh` before running!

#### CLO: Prefix installation path: `[-p=<PATH>]`, `[--prefix=<PATH>]`
```bash
  $> ./candi.sh --prefix=Your/Prefix/Path
```

#### CLO: Using multiple build processes `[-j<N>]`, `[--PROCS=<N>]`
```bash
  $> ./candi.sh -j<N>
```
* Remark: there is no whitespace character allowed between `-j` and the number `<N>`.
* Example: using 2 build processes `./candi.sh -j2` or `./candi.sh --PROCS=2`.
* Be careful with that! You need to have enough system memory (e.g. at least 8GB for using 2 or more processes).

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


Switching candi to other Projects (e.g. FEniCS)
----

You can switch the current project to handle to your needs.
For doing this, firstly find out which projects are currently bundled with candi by
```bash
  $> ls project-*.cfg
```
This gives you a list of the currently configured projects.

If you want to switch to a currently configured project, e.g. to project-FEniCS.cfg, type
```bash
  $> ./switch-project-to FEniCS
```

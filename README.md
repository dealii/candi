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
Make sure, that you are in the downloaded folder of candi; e.g. after the download type
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
* Set up of the needed compilers.

#### Install deal.II on RHEL 7, CentOS 7 or Fedora 20/21:
```bash
  $> module load mpi/openmpi-`uname -i`
  $> export CC=mpicc; export CXX=mpicxx; export FC=mpif90; export FF=mpif77
  $> ./candi.sh
```
Hit return and wait.

Adapting candi to your needs
----

You can adapt several things to your personal needs, this includes the individual choice for
* the DOWNLOAD folder (can be safely removed after installation),
* the UNPACK folder of the downloaded packages (can be safely removed after installation),
* the BUILD folder (can be safely removed after installation),
* the INSTALLATION destination folder,
and more options.

Edit the file behind the softlink "candi.cfg", e.g.
```bash
  $> gedit candi.cfg
```

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

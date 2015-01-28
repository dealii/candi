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

### deal.II Library with Trilinos, PetSc, MPI Support, and more:

candi is initially configured to compile and install the current version of the deal.II library.

```bash
 $> cd candi
 $> ./candi.sh
```

* Abort the installer by pressing < CTRL > + C
* Read Carefully the instructions!
* Install the needed packages from your distribution. (For that, you need super user rights.)
* Set up of the needed compilers

#### Install deal.II on RHEL 7, CentOS 7 or Fedora 20/21:
```bash
  $> module load mpi/openmpi-`uname -i`
  $> export CC=mpicc; export CXX=mpicxx; export FC=mpif90; export FF=mpif77
  $> ./candi.sh
```
Hit return and wait.

FROM ubuntu:24.04

MAINTAINER timo.heister@gmail.com

ARG TAG=v9.8.0-r1

# Set the locale
# this is required so that numbers can be formatted with , separators
RUN apt-get update && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -yq --no-install-recommends \
    adduser \
    ca-certificates \
    patch \
    bzip2 \
    make \
    g++ \
    gcc \
    gfortran \
    git \
    gsl-bin \
    libblas-dev \
    libbz2-dev \
    libgsl-dev \
    liblapack-dev \
    locales \
    ninja-build \
    numdiff \
    unzip \
    wget \
    zlib1g-dev \
    libmpich-dev \
    mpich \
    python3 \
    cmake \
    m4 \
    sudo \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# add and enable the default user
ARG USER=dealii
RUN adduser --disabled-password --gecos '' $USER
RUN adduser $USER sudo; echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

#make sure everything is in place
RUN chown -R $USER:$USER /home/$USER
USER $USER
ENV HOME /home/$USER
ENV USER $USER
WORKDIR $HOME

USER root

# install astyle:
RUN \
    wget http://cecas.clemson.edu/dealii/mirror/astyle_2.04_linux.tar.gz && \
    tar xf astyle_2.04_linux.tar.gz && \
    cd astyle/build/gcc && \
    make && \
    USER=root make install && \
    cd - && \
    rm -rf astyle*


ENV HOME /home/$USER
WORKDIR $HOME
USER $USER

RUN echo "Building candi ref ${TAG}" && \
  git clone https://github.com/dealii/candi/ && \
  cd candi && git checkout "${TAG}" && \
  ./candi.sh -j8 \
        --prefix=$HOME/libs \
        --packages="load:dealii-prepare once:arpack-ng once:opencascade once:parmetis once:superlu_dist once:hdf5 once:netcdf once:p4est once:trilinos once:petsc once:slepc once:assimp once:sundials once:adolc once:gmsh" &&\
  rm -rf $HOME/candi $HOME/libs/tmp

# I don't know how to import env vars from the configuration folder.  This
# probably doesn't work at all, because we don't use bash but sh and so we can
# not use 'source' or any of the bash startup files. Manually export the paths
# here instead:
RUN cat ~/libs/configuration/* | grep export | sort

ENV ADOLC_DIR=/home/dealii/libs/adolc-2.7.2
ENV ARPACK_DIR=/home/dealii/libs/arpack-ng-3.8.0
ENV ASSIMP_DIR=/home/dealii/libs/assimp-4.1.0
ENV CASROOT=/home/dealii/libs/OCCT-7_9_3
ENV GMSH_DIR=/home/dealii/libs/gmsh-4.8.4
ENV HDF5_DIR=/home/dealii/libs/hdf5-1.12.2
ENV METIS_DIR=/home/dealii/libs/parmetis-4.0.3
ENV OPENCASCADE_DIR=/home/dealii/libs/OCCT-7_9_3
ENV P4EST_DIR=/home/dealii/libs/p4est-2.8.7
ENV PARMETIS_DIR=/home/dealii/libs/parmetis-4.0.3
ENV PATH=/home/dealii/libs/gmsh-4.8.4/bin:$PATH
ENV PETSC_DIR=/home/dealii/libs/petsc-3.24.3
ENV SLEPC_DIR=/home/dealii/libs/slepc-3.24.0
ENV SUNDIALS_DIR=/home/dealii/libs/sundials-6.7.0
ENV SUPERLU_DIR=/home/dealii/libs/superlu_dist_8.2.1
ENV TRILINOS_DIR=/home/dealii/libs/trilinos-release-16-2-0


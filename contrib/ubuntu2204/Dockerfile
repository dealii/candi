FROM ubuntu:22.04

USER root

RUN apt-get update && DEBIAN_FRONTEND="noninteractive" apt-get install -y \
      lsb-release git subversion wget bc libgmp-dev \
      build-essential autoconf automake cmake libtool gfortran python3 \
      zlib1g-dev \
      openmpi-bin openmpi-common libopenmpi-dev \
      libblas3 libblas-dev liblapack3 liblapack-dev libsuitesparse-dev \
    && rm -rf /var/lib/apt/lists/*

ARG USER=bob
RUN adduser --disabled-password --gecos '' $USER
RUN adduser $USER sudo; echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN chown -R $USER:$USER /home/$USER
USER $USER
ENV HOME /home/$USER
ENV USER $USER
ENV OMPI_MCA_btl "^vader"
WORKDIR $HOME

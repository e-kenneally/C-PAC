#using neurodebian runtime as parent image
FROM neurodebian:bionic-non-free
MAINTAINER The C-PAC Team <cnl@childmind.org>

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9

RUN apt-get update

RUN apt-get install apt-utils software-properties-common -y

RUN add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/'

RUN apt-get update

# Install the validator
RUN apt-get install -y curl && \
     curl -sL https://deb.nodesource.com/setup_11.x | bash - && \
     apt-get install -y nodejs
RUN npm install -g bids-validator

# Install Ubuntu dependencies and utilities
RUN apt-get install -y \
      build-essential \
      cmake \
      git \
      graphviz \
      graphviz-dev \
      gsl-bin \
      libcanberra-gtk-module \
      libexpat1-dev \
      libgiftiio-dev \
      libglib2.0-dev \
      libglu1-mesa \
      libglu1-mesa-dev \
      libjpeg-progs \
      libgl1-mesa-dri \
      libglw1-mesa \
      libxml2 \
      libxml2-dev \
      libxext-dev \
      libxft2 \
      libxft-dev \
      libxi-dev \
      libxmu-headers \
      libxmu-dev \
      libxpm-dev \
      libxslt1-dev \
      m4 \
      make \
      mesa-common-dev \
      mesa-utils \
      netpbm \
      pkg-config \
      tcsh \
      unzip \
      vim \
      xvfb \
      xauth \
      zlib1g-dev

# Install 16.04 dependencies
RUN apt-get install -y \
      dh-autoreconf \
      libgsl-dev \
      libmotif-dev \
      libtool \
      libx11-dev \
      libxext-dev \
      x11proto-xext-dev \
      x11proto-print-dev \
      xutils-dev

# Install 18.04 dependencies
RUN apt-get install -y \
      eog \
      evince \
      firefox \
      gedit \
      gnome-icon-theme-symbolic \
      gnome-terminal \
      gnome-tweak-tool \
      gsl-bin \
      libcurl4-openssl-dev \
      libgfortran3 \
      libjpeg62 \
      libssl-dev \
      libxm4 \
      nautilus \
      python-qt4 \
      r-base \
      xfonts-base \
      xfonts-100dpi \
      xterm

# Compiles libxp- this is necessary for some newer versions of Ubuntu
# where the is no Debian package available.
RUN git clone git://anongit.freedesktop.org/xorg/lib/libXp /tmp/libXp && \
    cd /tmp/libXp && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install && \
    cd - && \
    rm -rf /tmp/libXp

# Installing and setting up c3d
RUN mkdir -p /opt/c3d && \
    curl -sSL "http://downloads.sourceforge.net/project/c3d/c3d/1.0.0/c3d-1.0.0-Linux-x86_64.tar.gz" \
    | tar -xzC /opt/c3d --strip-components 1
ENV C3DPATH /opt/c3d/
ENV PATH $C3DPATH/bin:$PATH

# install AFNI
COPY dev/docker_data/required_afni_pkgs.txt /opt/required_afni_pkgs.txt
RUN libs_path=/usr/lib/x86_64-linux-gnu && \
    if [ -f $libs_path/libgsl.so.19 ]; then \
        ln $libs_path/libgsl.so.19 $libs_path/libgsl.so.0; \
    fi && \
    ln -s $libs_path/libgsl.so.23 /$libs_path/libgsl.so.19 && \
    mkdir -p /opt/afni && \
    curl -O https://afni.nimh.nih.gov/pub/dist/bin/linux_ubuntu_16_64/@update.afni.binaries && \
    tcsh @update.afni.binaries -package linux_ubuntu_16_64  -do_extras
ENV PATH /root/abin:$PATH
RUN rPkgsInstall -pkgs ALL && \
    rm -rf @update.afni.binaries && \
    cp $HOME/abin/AFNI.afnirc $HOME/.afnirc && \
    suma -update_env && \
    @update.afni.binaries -d
RUN curl -O https://afni.nimh.nih.gov/pub/dist/edu/data/CD.tgz && \
    tar xvzf CD.tgz && \
    cd CD && \
    tcsh s2.cp.files . ~ && \
    cd ..
RUN afni_system_check.py -check_all


# install FSL
RUN apt-get install -y --no-install-recommends \
      fsl-core \
      fsl-atlases \
      fsl-mni152-templates

# setup FSL environment
ENV FSLDIR=/usr/share/fsl/5.0 \
    FSLOUTPUTTYPE=NIFTI_GZ \
    FSLMULTIFILEQUIT=TRUE \
    POSSUMDIR=/usr/share/fsl/5.0 \
    LD_LIBRARY_PATH=/usr/lib/fsl/5.0:$LD_LIBRARY_PATH \
    FSLTCLSH=/usr/bin/tclsh \
    FSLWISH=/usr/bin/wish \
    PATH=/usr/lib/fsl/5.0:$PATH

# install CPAC resources into FSL
RUN curl -sL http://fcon_1000.projects.nitrc.org/indi/cpac_resources.tar.gz -o /tmp/cpac_resources.tar.gz && \
    tar xfz /tmp/cpac_resources.tar.gz -C /tmp && \
    cp -n /tmp/cpac_image_resources/MNI_3mm/* $FSLDIR/data/standard && \
    cp -n /tmp/cpac_image_resources/MNI_4mm/* $FSLDIR/data/standard && \
    cp -n /tmp/cpac_image_resources/symmetric/* $FSLDIR/data/standard && \
    cp -n /tmp/cpac_image_resources/HarvardOxford-lateral-ventricles-thr25-2mm.nii.gz $FSLDIR/data/atlases/HarvardOxford && \
    cp -nr /tmp/cpac_image_resources/tissuepriors/2mm $FSLDIR/data/standard/tissuepriors && \
    cp -nr /tmp/cpac_image_resources/tissuepriors/3mm $FSLDIR/data/standard/tissuepriors

# download OASIS templates for niworkflows-ants skullstripping
RUN mkdir /ants_template && \
    curl -sL https://s3-eu-west-1.amazonaws.com/pfigshare-u-files/3133832/Oasis.zip -o /tmp/Oasis.zip && \
    unzip /tmp/Oasis.zip -d /tmp &&\
    mv /tmp/MICCAI2012-Multi-Atlas-Challenge-Data /ants_template/oasis && \
    rm -rf /tmp/Oasis.zip /tmp/MICCAI2012-Multi-Atlas-Challenge-Data

# install ANTs
ENV PATH=/usr/lib/ants:$PATH
RUN apt-get install -y ants

# install ICA-AROMA
RUN mkdir -p /opt/ICA-AROMA
RUN curl -sL https://github.com/rhr-pruim/ICA-AROMA/archive/v0.4.3-beta.tar.gz | tar -xzC /opt/ICA-AROMA --strip-components 1
RUN chmod +x /opt/ICA-AROMA/ICA_AROMA.py
ENV PATH=/opt/ICA-AROMA:$PATH

# install miniconda
RUN curl -sO https://repo.continuum.io/miniconda/Miniconda3-4.7.12.1-Linux-x86_64.sh && \
    bash Miniconda3-4.7.12.1-Linux-x86_64.sh -b -p /usr/local/miniconda && \
    rm Miniconda3-4.7.12.1-Linux-x86_64.sh

# update path to include conda
ENV PATH=/usr/local/miniconda/bin:$PATH

# install blas dependency first
RUN conda install -y \
        blas

# install conda dependencies
RUN conda install -y  \
        matplotlib \
        networkx \
        nose \
        numpy \
        pandas \
        scipy \
        traits \
        wxpython \
        pip

# install torch
RUN pip install torch torchvision -f https://download.pytorch.org/whl/torch_stable.html

# install python dependencies
COPY requirements.txt /opt/requirements.txt
RUN pip install --upgrade setuptools
RUN pip install --upgrade pip
RUN pip install -r /opt/requirements.txt
RUN pip install xvfbwrapper

# install PyPEER
RUN pip install git+https://github.com/ChildMindInstitute/PyPEER.git

# install cpac templates
ADD dev/docker_data/cpac_templates.tar.gz /

RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
RUN apt-get install git-lfs
RUN git lfs install

# Get atlases
RUN mkdir -p /ndmg_atlases/label && \
    GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/neurodata/neuroparc.git /tmp/neuroparc && \
    cd /tmp/neuroparc && \
    git lfs install --skip-smudge && \
    git lfs pull -I "atlases/label/Human/*" && \
    cp -r /tmp/neuroparc/atlases/label/Human /ndmg_atlases/label && \
    cd -

COPY dev/docker_data/default_pipeline.yml /cpac_resources/default_pipeline.yml
COPY dev/circleci_data/pipe-test_ci.yml /cpac_resources/pipe-test_ci.yml


COPY . /code
RUN pip install -e /code

COPY dev/docker_data /code/docker_data
RUN mv /code/docker_data/* /code && rm -Rf /code/docker_data && chmod +x /code/run.py

ENTRYPOINT ["/code/run.py"]


RUN apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

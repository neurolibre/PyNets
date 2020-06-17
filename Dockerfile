FROM debian:stretch-slim

# Pre-cache neurodebian key
COPY docker/files/neurodebian.gpg /root/.neurodebian.gpg

ARG DEBIAN_FRONTEND="noninteractive"

ENV LANG="C.UTF-8" \
    LC_ALL="C.UTF-8"

RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends software-properties-common \
    # Install system dependencies.
    && apt-get install -y --no-install-recommends \
        bzip2 \
        ca-certificates \
        curl \
        libxtst6 \
        libgtk2.0-bin \
        libxft2 \
        lib32ncurses5 \
        libxmu-dev \
        vim \
        wget \
        libgl1-mesa-glx \
        graphviz \
        libpng-dev \
        gnupg \
        build-essential \
        libgomp1 \
        libmpich-dev \
        mpich \
        git \
        g++ \
        zip \
        unzip \
        libglu1 \
        zlib1g-dev \
        libfreetype6-dev \
        pkg-config \
        libgsl0-dev \
        openssl \
	    openssh-server \
        gsl-bin \
        libglu1-mesa-dev \
        libglib2.0-0 \
        libglw1-mesa \
	liblapack-dev \
	libopenblas-base \
	sqlite3 \
	libsqlite3-dev \
	libquadmath0 \
    # Configure ssh
    && mkdir /var/run/sshd \
    && echo 'root:screencast' | chpasswd \
    && sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd \
    # Add and configure git-lfs
    && apt-get install -y apt-transport-https debian-archive-keyring \
    && apt-get install -y dirmngr --install-recommends \
    && curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
    apt-get update && \
    apt-get install -y git-lfs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && curl -o /tmp/libxp6.deb -sSL http://mirrors.kernel.org/debian/pool/main/libx/libxp/libxp6_1.0.2-2_amd64.deb \
    && dpkg -i /tmp/libxp6.deb && rm -f /tmp/libxp6.deb \
    # Add new user.
    && groupadd -r dpisner && useradd --no-log-init --create-home --shell /bin/bash -r -g dpisner dpisner \
    && chmod a+s /opt \
    && chmod 777 -R /opt \
    && apt-get clean -y && apt-get autoclean -y && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && curl -sSL https://fsl.fmrib.ox.ac.uk/fsldownloads/fsl-6.0.2-centos7_64.tar.gz | tar xz -C /usr/local \
       --exclude='fsl/doc' \
       --exclude='fsl/data/first' \
       --exclude='fsl/data/atlases' \
       --exclude='fsl/data/possum' \
       --exclude='fsl/src' \
       --exclude='fsl/extras/src' \
       --exclude='fsl/bin/fslview*' \
       --exclude='fsl/bin/FSLeyes' \
       --exclude='fsl/bin/*_gpu*' \
       --exclude='fsl/bin/*_cuda*' \
    && chmod 777 -R /usr/local/fsl/bin \
    && chown -R dpisner:dpisner /usr/local/fsl

ARG NB_USER=jovyan
ARG NB_UID=1000
ENV USER ${NB_USER}
ENV NB_UID ${NB_UID}
ENV HOME /home/${NB_USER}

RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    ${NB_USER}
    
# Make sure the contents of our repo are in ${HOME}
COPY . ${HOME}
USER root
RUN chown -R ${NB_UID} ${HOME}
USER ${NB_USER}
WORKDIR /home/${NB_USER}

# Install Miniconda, python, and basic packages.
ARG miniconda_version="4.3.27"
ENV PATH="/opt/conda/bin":$PATH
RUN curl -sSLO https://repo.continuum.io/miniconda/Miniconda3-${miniconda_version}-Linux-x86_64.sh \
    && bash Miniconda3-${miniconda_version}-Linux-x86_64.sh -b -p /opt/conda \
    && conda config --system --prepend channels conda-forge \
    && conda config --system --set auto_update_conda false \
    && conda config --system --set show_channel_urls true \
    && conda clean -tipsy \
    && conda install -yq python=3.6 ipython \
    && pip install --upgrade pip \
    && conda clean -tipsy \
    && rm -rf Miniconda3-${miniconda_version}-Linux-x86_64.sh \
    && pip install numpy requests psutil sqlalchemy \
    # Install pynets
    && git clone -b development https://github.com/dPys/PyNets /home/${NB_USER}/PyNets && \
    cd /home/${NB_USER}/PyNets && \
    pip install -r requirements.txt && \
    python setup.py install \
    # Install skggm
    && conda install -yq \
        cython \
        libgfortran \
        matplotlib \
        openblas \
    && conda clean -tipsy \
    && pip install skggm python-dateutil==2.8.0 \
    && sed -i '/mpl_patches = _get/,+3 d' /opt/conda/lib/python3.6/site-packages/nilearn/plotting/glass_brain.py \
    && sed -i '/for mpl_patch in mpl_patches:/,+2 d' /opt/conda/lib/python3.6/site-packages/nilearn/plotting/glass_brain.py \
    # Precaching fonts, set 'Agg' as default backend for matplotlib
    && python -c "from matplotlib import font_manager" \
    && sed -i 's/\(backend *: \).*$/\1Agg/g' $( python -c "import matplotlib; print(matplotlib.matplotlib_fname())" ) \
    # Create nipype config for resource monitoring
    && mkdir -p ~/.nipype \
    && echo "[monitoring]" > ~/.nipype/nipype.cfg \
    && echo "enabled = true" >> ~/.nipype/nipype.cfg \
    && pip uninstall -y pandas \
    && pip install pandas -U \
    && rm -rf /home/${NB_USER}/PyNets \
    && rm -rf /home/${NB_USER}/.cache

# Handle permissions, cleanup, and create mountpoints
USER root

#Neurolibre specific configurations : https://mybinder.readthedocs.io/en/latest/tutorials/dockerfile.html
RUN pip install --no-cache-dir notebook==5.*

RUN chmod a+s -R /opt \
    && chown -R dpisner /opt/conda/lib/python3.6/site-packages \
    && mkdir -p /home/${NB_USER}/.pynets \
    && chown -R dpisner /${NB_USER}/dpisner/.pynets \
    && chmod 777 /opt/conda/bin/pynets \
    && chmod 777 -R /${NB_USER}/dpisner/.pynets \
    && chmod 777 /opt/conda/bin/pynets \
    && chmod 777 /opt/conda/bin/pynets_bids \
    && chmod 777 /opt/conda/bin/pynets_collect \
    && chmod 777 /opt/conda/bin/pynets_cloud \
    && find /opt/conda/lib/python3.6/site-packages -type f -iname "*.py" -exec chmod 777 {} \; \
    && find /opt -type f -iname "*.py" -exec chmod 777 {} \; \
    && find /opt -type f -iname "*.yaml" -exec chmod 777 {} \; \
    && apt-get purge -y --auto-remove \
	git \
	gcc \
	wget \
	curl \
	build-essential \
	ca-certificates \
	gnupg \
	g++ \
	openssl \
	git-lfs \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && conda clean -tipsy \
    && mkdir /inputs && \
    chmod -R 777 /inputs \
    && mkdir /outputs && \
    chmod -R 777 /outputs \
    && mkdir /working && \
    chmod -R 777 /working

USER ${NB_USER}

# ENV Config
ENV LD_LIBRARY_PATH="/opt/conda/lib":$LD_LIBRARY_PATH
ENV PATH="/opt/conda/lib/python3.6/site-packages/pynets":$PATH
ENV FSLDIR=/usr/local/fsl
ENV FSLOUTPUTTYPE=NIFTI_GZ
ENV PATH=/usr/local/fsl/bin:$PATH
ENV FSLMULTIFILEQUIT=TRUE
ENV LD_LIBRARY_PATH="/usr/local/fsl":$LD_LIBRARY_PATH
ENV FSLTCLSH=/usr/bin/tclsh
ENV FSLWISH=/usr/bin/wish
ENV FSLBROWSER=/etc/alternatives/x-www-browser
ENV LD_LIBRARY_PATH="/usr/lib/openblas-base":$LD_LIBRARY_PATH
ENV PYTHONWARNINGS ignore
ENV OMP_NUM_THREADS=1
ENV USE_SIMPLE_THREADED_LEVEL3=1

EXPOSE 22

# and add it as an entrypoint
#ENTRYPOINT ["pynets_bids"]

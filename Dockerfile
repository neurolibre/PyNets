FROM nipype/nipype:py36

# BinderHub requirements
# creating notebook user
ARG NB_USER=jovyan
ENV USER ${NB_USER}
ENV HOME /home/${NB_USER}

USER root
RUN useradd -ms /bin/bash ${NB_USER}

#fsl
RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends wget
RUN wget -O- http://neuro.debian.net/lists/bionic.us-ca.full | tee /etc/apt/sources.list.d/neurodebian.sources.list
RUN apt-key adv --recv-keys --keyserver hkp://pool.sks-keyservers.net:80 0xA5D32F012649A5A9
RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends fsl-complete

# Make sure the contents of the repo are in ${HOME}
COPY . ${HOME}
RUN chown -R ${NB_USER} ${HOME}
RUN chgrp -R ${NB_USER} ${HOME}
WORKDIR /home/${NB_USER}

RUN pip install --no-cache --upgrade pip \
    &&  pip install --no-cache notebook==5.*

#pynets
RUN git clone -b development https://github.com/dPys/PyNets /home/${NB_USER}/PyNets \
    && cd /home/${NB_USER}/PyNets \
    && pip install -r requirements.txt \
    && python setup.py install
    
# Create nipype config for resource monitoring
RUN mkdir -p /home/${NB_USER}/.nipype \
    && echo "[monitoring]" > /home/${NB_USER}/.nipype/nipype.cfg \
    && echo "enabled = true" >> /home/${NB_USER}/.nipype/nipype.cfg

ENV LD_LIBRARY_PATH="/opt/conda/lib":$LD_LIBRARY_PATH
ENV PATH="/opt/conda/lib/python3.6/site-packages/pynets":$PATH
ENV FSLDIR=/usr/local/fsl
ENV FSLOUTPUTTYPE=NIFTI_GZ
ENV FSLMULTIFILEQUIT=TRUE
ENV LD_LIBRARY_PATH="/usr/lib/openblas-base":$LD_LIBRARY_PATH
ENV PYTHONWARNINGS ignore
ENV OMP_NUM_THREADS=1
ENV USE_SIMPLE_THREADED_LEVEL3=1

USER ${NB_USER}
RUN chown -R ${NB_USER} ${HOME}
RUN chgrp -R ${NB_USER} ${HOME}

#Disabling entrypoints
ENTRYPOINT []

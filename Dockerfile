FROM dpys/pynets:latest

# BinderHub requirements
ARG NB_USER=jovyan
ARG NB_UID=1000
ENV USER ${NB_USER}
ENV NB_UID ${NB_UID}
ENV HOME /home/${NB_USER}

USER root
RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    ${NB_USER}

# Make sure the contents of the repo are in ${HOME}
COPY . ${HOME}
RUN chown -R ${NB_UID} ${HOME}
RUN chgrp -R ${NB_UID} ${HOME}
WORKDIR /home/${NB_USER}
USER ${NB_USER}

RUN pip install --no-cache --upgrade pip && \
    pip install --no-cache notebook==5.*

#Disabling entrypoints
ENTRYPOINT []

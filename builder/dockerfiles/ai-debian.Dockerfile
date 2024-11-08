# ucf-tdm-debian

ARG from
FROM ${from} AS base
LABEL org.opencontainers.image.authors="armando.ucf@gmail.com"

ARG uname=ezdev
ARG gname=ezdev
ARG py_dir="/opt/py"
ARG venv="base"

ENV DEBIAN_FRONTEND=noninteractive
#ENV TZ=UTC
#RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

SHELL ["/bin/bash", "-l", "-c"]

USER root

# runtime dependencies
RUN set -eux; \
	  apt-get -q update; \
	  apt-get -qq install -y --no-install-recommends \
		  graphviz graphviz-dev \
	  ; \
   apt-get -q autoremove --purge ; apt-get -q clean ; rm -rf /var/lib/apt/lists/* \
   rm -rf /usr/share/doc/ ; rm -rf /usr/share/man/ ; rm -rf /usr/share/locale/

FROM base AS py-cpu-debian-build

RUN set -eux; \
    apt-get -q update; \
    apt-get -qq install -y --no-install-recommends \
      build-essential \
    ; \
    apt-get -q autoremove --purge ; apt-get -q clean ; rm -rf /var/lib/apt/lists/* \
    rm -rf /usr/share/doc/ ; rm -rf /usr/share/man/ ; rm -rf /usr/share/locale/

COPY pyenv/pytorch-pip.txt /root/requirements.txt
RUN pip install -r /root/requirements.txt --index-url https://download.pytorch.org/whl/cpu && \
    rm -rf /root/requirements.txt

COPY pyenv/fm-cpu.txt /root/requirements.txt
RUN pip install -r /root/requirements.txt && \
    rm -rf /root/requirements.txt
        
COPY pyenv/fm.txt /root/requirements.txt
RUN pip install -r /root/requirements.txt && \
    rm -rf /root/requirements.txt

COPY pyenv/fm-pip.txt /root/requirements.txt
RUN pip install -r /root/requirements.txt && \
    rm -rf /root/requirements.txt

COPY pyenv/ai-core.txt /root/requirements.txt
RUN pip install -r /root/requirements.txt && \
    rm -rf /root/requirements.txt

FROM base AS py-gpu-debian-build

RUN set -eux; \
    apt-get -q update; \
    apt-get -qq install -y --no-install-recommends \
      build-essential \
    ; \
    apt-get -q autoremove --purge ; apt-get -q clean ; rm -rf /var/lib/apt/lists/* \
    rm -rf /usr/share/doc/ ; rm -rf /usr/share/man/ ; rm -rf /usr/share/locale/

COPY pyenv/pytorch-pip.txt /root/requirements.txt
RUN pip install -r /root/requirements.txt && \
    rm -rf /root/requirements.txt

COPY pyenv/fm-gpu.txt /root/requirements.txt
RUN pip install -r /root/requirements.txt && \
    rm -rf /root/requirements.txt
        
COPY pyenv/fm.txt /root/requirements.txt
RUN pip install -r /root/requirements.txt && \
    rm -rf /root/requirements.txt

COPY pyenv/fm-pip.txt /root/requirements.txt
RUN pip install -r /root/requirements.txt && \
    rm -rf /root/requirements.txt

COPY pyenv/ai-core.txt /root/requirements.txt
RUN pip install -r /root/requirements.txt && \
    rm -rf /root/requirements.txt

FROM base AS py-cpu-debian-final

COPY --from=py-cpu-debian-build ${py_dir} ${py_dir}
RUN chmod -R o+rw ${py_dir}
USER ${uname}

FROM base AS py-gpu-debian-final

COPY --from=py-gpu-debian-build ${py_dir} ${py_dir}
RUN chmod -R o+rw ${py_dir}
USER ${uname}

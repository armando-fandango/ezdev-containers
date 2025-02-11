# ucf-tdm-debian

ARG from
FROM ${from} AS base
LABEL org.opencontainers.image.authors="armando.ucf@gmail.com"

ARG uname=ezdev
ARG gname=ezdev
ARG py_dir="/opt/py"
ARG venv="base"
ARG project_name="ucf-tdm"

ENV DEBIAN_FRONTEND=noninteractive
#ENV TZ=UTC
#RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

SHELL ["/bin/bash", "-l", "-c"]

USER root

RUN apt-get -q update \
    && apt-get -qq install -y --no-install-recommends \
      xxd ca-certificates \ 
    && apt-get -q autoremove --purge && apt-get -q clean && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/share/doc/ && rm -rf /usr/share/man/ && rm -rf /usr/share/locale/ \
    && update-ca-certificates \
    && curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR=/usr/local/bin sh -s 0.32.3 \
    # add the dialout group to user uname:gname with uid:gid
    && usermod -a -G dialout ${uname}

USER ${uname}
WORKDIR /home/${uname}
RUN arduino-cli config init --additional-urls "https://espressif.github.io/arduino-esp32/package_esp32_index.json" --config-file /home/${uname}/.arduino15/arduino-cli.yaml \
&& arduino-cli core update-index \
&& arduino-cli core install esp32:esp32@2.0.9

USER root

FROM base AS py-cpu-debian-build

#RUN apt-get update; \
#apt-get install -y --no-install-recommends \
#    build-essential \
#; \
#rm -rf /var/lib/apt/lists/*
COPY pytorch-pip.txt /root/requirements.txt
RUN pip install -r /root/requirements.txt --index-url https://download.pytorch.org/whl/cpu && \
    rm -rf /root/requirements.txt

COPY ${project_name}-cpu.txt /root/requirements.txt
RUN pip install -r /root/requirements.txt && \
    sed -i "s|np.dtype(np.float_)|#np.dtype(np.float_)|g" /opt/py/lib/python3.10/site-packages/tvm/_ffi/runtime_ctypes.py && \
    rm -rf /root/requirements.txt

FROM base AS py-gpu-debian-build

COPY pytorch-pip.txt /root/requirements.txt
RUN pip install -r /root/requirements.txt && \
    rm -rf /root/requirements.txt

COPY ${project_name}-gpu.txt /root/requirements.txt
RUN pip install -r /root/requirements.txt && \
    sed -i "s|np.dtype(np.float_)|#np.dtype(np.float_)|g" /opt/py/lib/python3.10/site-packages/tvm/_ffi/runtime_ctypes.py && \
    rm -rf /root/requirements.txt

FROM base AS py-cpu-debian-final

COPY --from=py-cpu-debian-build ${py_dir} ${py_dir}
RUN chmod -R o+rw ${py_dir}
USER ${uname}

FROM base AS py-gpu-debian-final

COPY --from=py-gpu-debian-build ${py_dir} ${py_dir}
RUN chmod -R o+rw ${py_dir}
USER ${uname}

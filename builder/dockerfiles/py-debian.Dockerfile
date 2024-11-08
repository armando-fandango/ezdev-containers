ARG from
FROM ${from} AS py-base
LABEL org.opencontainers.image.authors="armando.ucf@gmail.com"

ARG uname=ezdev
ARG gname=ezdev
ARG py_dir="/opt/py"
ARG venv="base"

ENV DEBIAN_FRONTEND=noninteractive
#ENV TZ=UTC
#RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
ENV MAMBA_NO_BANNER=1
ENV PATH=${py_dir}/bin:$PATH
# cannot remove LANG even though https://bugs.python.org/issue19846 is fixed
# last attempted removal of LANG broke many users:
# https://github.com/docker-library/python/pull/570
ENV LANG C.UTF-8

SHELL ["/bin/bash","-l","-c"]

USER ${uname}
WORKDIR /home/${uname}
RUN echo -e "\nPATH=${py_dir}/bin:\$PATH\n" >> ~/.bashrc

USER root
#ENV HOME=/root
RUN echo -e "\nPATH=${py_dir}/bin:\$PATH\n" >> ~/.bashrc


FROM py-base AS py-310-build

# runtime dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		netbase \
		tzdata \
	; \
	rm -rf /var/lib/apt/lists/*

ENV PYTHON_VERSION 3.10.15
ENV GPG_KEY A035C8C19219BA821ECEA86B64E628F8D684696D

#ENV PYTHON_VERSION 3.11.10
#ENV GPG_KEY A035C8C19219BA821ECEA86B64E628F8D684696D

#ENV PYTHON_VERSION=3.12.4
#ENV GPG_KEY 7169605F62C751356D054A26A821E680E5FA6305


RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		dpkg-dev \
		gcc \
		gnupg \
		libbluetooth-dev \
		libbz2-dev \
		libc6-dev \
		libdb-dev \
		libexpat1-dev \
		libffi-dev \
		libgdbm-dev \
		liblzma-dev \
		libncursesw5-dev \
		libreadline-dev \
		libsqlite3-dev \
		libssl-dev \
		make \
		tk-dev \
		uuid-dev \
		wget \
		xz-utils \
		zlib1g-dev \
	; \
	\
	wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz"; \
	wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc"; \
	GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$GPG_KEY"; \
	gpg --batch --verify python.tar.xz.asc python.tar.xz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" python.tar.xz.asc; \
	mkdir -p /usr/src/python; \
	tar --extract --directory /usr/src/python --strip-components=1 --file python.tar.xz; \
	rm python.tar.xz; \
	\
	cd /usr/src/python; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	./configure \
		--build="$gnuArch" \
		--enable-loadable-sqlite-extensions \
		--enable-optimizations \
		--enable-option-checking=fatal \
		--enable-shared \
		--with-lto \
		--with-system-expat \
		--with-ensurepip \
    --prefix=${py_dir} \
	; \
	nproc="$(nproc)"; \
	EXTRA_CFLAGS="$(dpkg-buildflags --get CFLAGS)"; \
	LDFLAGS="$(dpkg-buildflags --get LDFLAGS)"; \
	LDFLAGS="${LDFLAGS:--Wl},--strip-all"; \
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:-}" \
		"PROFILE_TASK=${PROFILE_TASK:-}" \
	; \
# https://github.com/docker-library/python/issues/784
# prevent accidental usage of a system installed libpython of the same version
	rm python; \
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:--Wl},-rpath='\$\$ORIGIN/../lib'" \
		"PROFILE_TASK=${PROFILE_TASK:-}" \
		python \
	; \
	make install; \
	\
	cd /; \
	rm -rf /usr/src/python; \
	\
	find ${py_dir} -depth \
		\( \
			\( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
			-o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name 'libpython*.a' \) \) \
		\) -exec rm -rf '{}' + \
	; \
	\
	ldconfig; \
	\
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec ldd '{}' ';' \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*; \
	\
	export PYTHONDONTWRITEBYTECODE=1; \
	${py_dir}/bin/python3 --version; \
  \
  pip3 install \
    --disable-pip-version-check \
    --no-cache-dir \
    --no-compile \
    'setuptools==65.5.1' \
    wheel \
  ; \
	${py_dir}/bin/pip3 --version

# make some useful symlinks that are expected to exist ("/usr/local/bin/python" and friends)
RUN set -eux; \
	for src in idle3 pip3 pydoc3 python3 python3-config; do \
		dst="$(echo "$src" | tr -d 3)"; \
		[ -s "${py_dir}/bin/$src" ]; \
		[ ! -e "${py_dir}/bin/$dst" ]; \
		ln -svT "$src" "${py_dir}/bin/$dst"; \
	done

COPY pyenv/core.txt /root/

RUN  PATH=${py_dir}/bin:$PATH \
  && pip install -r  /root/core.txt \
  && rm -rf /root/core.txt 

FROM py-base AS py-312-build

# ensure local python is preferred over distribution python
#ENV PATH /usr/local/bin:$PATH

# cannot remove LANG even though https://bugs.python.org/issue19846 is fixed
# last attempted removal of LANG broke many users:
# https://github.com/docker-library/python/pull/570
ENV LANG C.UTF-8

# runtime dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		netbase \
		tzdata \
	; \
	rm -rf /var/lib/apt/lists/*

#ENV PYTHON_VERSION 3.10.15
#ENV GPG_KEY A035C8C19219BA821ECEA86B64E628F8D684696D

#ENV PYTHON_VERSION 3.11.10
#ENV GPG_KEY A035C8C19219BA821ECEA86B64E628F8D684696D

ENV PYTHON_VERSION=3.12.4
ENV GPG_KEY 7169605F62C751356D054A26A821E680E5FA6305

RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		dpkg-dev \
		gcc \
		gnupg \
		libbluetooth-dev \
		libbz2-dev \
		libc6-dev \
		libdb-dev \
		libexpat1-dev \
		libffi-dev \
		libgdbm-dev \
		liblzma-dev \
		libncursesw5-dev \
		libreadline-dev \
		libsqlite3-dev \
		libssl-dev \
		make \
		tk-dev \
		uuid-dev \
		wget \
		xz-utils \
		zlib1g-dev \
	; \
	\
	wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz"; \
	wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc"; \
	GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$GPG_KEY"; \
	gpg --batch --verify python.tar.xz.asc python.tar.xz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" python.tar.xz.asc; \
	mkdir -p /usr/src/python; \
	tar --extract --directory /usr/src/python --strip-components=1 --file python.tar.xz; \
	rm python.tar.xz; \
	\
	cd /usr/src/python; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	./configure \
		--build="$gnuArch" \
		--enable-loadable-sqlite-extensions \
		--enable-optimizations \
		--enable-option-checking=fatal \
		--enable-shared \
		--with-lto \
		--with-system-expat \
		--with-ensurepip \
    --prefix=${py_dir} \
	; \
	nproc="$(nproc)"; \
	EXTRA_CFLAGS="$(dpkg-buildflags --get CFLAGS)"; \
	LDFLAGS="$(dpkg-buildflags --get LDFLAGS)"; \
	LDFLAGS="${LDFLAGS:--Wl},--strip-all"; \
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:-}" \
		"PROFILE_TASK=${PROFILE_TASK:-}" \
	; \
# https://github.com/docker-library/python/issues/784
# prevent accidental usage of a system installed libpython of the same version
	rm python; \
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:--Wl},-rpath='\$\$ORIGIN/../lib'" \
		"PROFILE_TASK=${PROFILE_TASK:-}" \
		python \
	; \
	make install; \
	\
	cd /; \
	rm -rf /usr/src/python; \
	\
	find ${py_dir} -depth \
		\( \
			\( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
			-o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name 'libpython*.a' \) \) \
		\) -exec rm -rf '{}' + \
	; \
	\
	ldconfig; \
	\
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec ldd '{}' ';' \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*; \
	\
	export PYTHONDONTWRITEBYTECODE=1; \
	${py_dir}/bin/python3 --version; \
	${py_dir}/bin/pip3 --version

# make some useful symlinks that are expected to exist ("/usr/local/bin/python" and friends)
RUN set -eux; \
	for src in idle3 pip3 pydoc3 python3 python3-config; do \
		dst="$(echo "$src" | tr -d 3)"; \
		[ -s "${py_dir}/bin/$src" ]; \
		[ ! -e "${py_dir}/bin/$dst" ]; \
		ln -svT "$src" "${py_dir}/bin/$dst"; \
	done

COPY pyenv/core.txt /root/

RUN  PATH=${py_dir}/bin:$PATH \
  && pip install -r  /root/core.txt \
  && rm -rf /root/core.txt 

FROM py-base AS mamba-build

RUN apt-get -q update \ 
    && apt-get -qq install -y --no-install-recommends \
      wget ca-certificates
#&& chmod +rx /opt 
    # && chown -R ${uname}:${gname} ${mamba_dir}

#COPY --chown=${uname}:${gname} pyenv ${home}/pyenv
#COPY pyenv /root/pyenv
COPY pyenv/pyenv.sh /root/
COPY pyenv/core.yml /root/

#ARG activate="mamba activate ${venv} && umask 0000"
RUN mkdir -p ${py_dir} \
    && source /root/pyenv.sh \ 
    && umask 0000 \
    && ez_install_mamba \
    && rm -rf /root/pyenv.sh 

RUN conda config --system --set auto_activate_base true \
    && mamba env config vars set MAMBA_NO_BANNER=1 \
    && mamba init $(basename "${SHELL}")

RUN mamba env update -v -n ${venv} --file  /root/core.yml \
  && mamba clean -itcly \
  && rm -rf /root/core.yml 

FROM py-base AS py-310-final

USER root

# runtime dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		netbase \
		tzdata \
    libsqlite3-0 \
	; \
	rm -rf /var/lib/apt/lists/*

COPY --from=py-310-build ${py_dir} ${py_dir}

USER ${uname}
WORKDIR /home/${uname}

FROM py-base AS py-312-final

USER root

# runtime dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		netbase \
		tzdata \
    libsqlite3-0 \
	; \
	rm -rf /var/lib/apt/lists/*

COPY --from=py-312-build ${py_dir} ${py_dir}

USER ${uname}
WORKDIR /home/${uname}

FROM py-base AS mamba-final

USER root

COPY --from=mamba-build ${py_dir} ${py_dir}

RUN ${py_dir}/bin/conda config --system --set auto_activate_base true \
    && ${py_dir}/bin/mamba env config vars set MAMBA_NO_BANNER=1 \
    && ${py_dir}/bin/mamba init $(basename "${SHELL}")

USER ${uname}
WORKDIR /home/${uname}
#ENV HOME=/home/${uname}
#ENV MAMBA_NO_BANNER=1
#ENV PATH=${mamba_dir}/bin:$PATH
RUN ${py_dir}/bin/mamba init $(basename "${SHELL}") \
    && ${py_dir}/bin/mamba env config vars set MAMBA_NO_BANNER=1

FROM ${from} AS jupyter-base

ARG uname=ezdev
ARG gname=ezdev
ARG py_dir="/opt/py"
ARG venv="base"

ENV DEBIAN_FRONTEND=noninteractive
#ENV TZ=UTC
#RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
ENV MAMBA_NO_BANNER=1
ENV PATH=${py_dir}/bin:$PATH
# cannot remove LANG even though https://bugs.python.org/issue19846 is fixed
# last attempted removal of LANG broke many users:
# https://github.com/docker-library/python/pull/570
ENV LANG C.UTF-8

SHELL ["/bin/bash","-l","-c"]
USER root

FROM jupyter-base AS py-jupyter-build

COPY pyenv/jupyter.txt /root/jupyter.txt
RUN pip install -r  /root/jupyter.txt && \
  rm /root/jupyter.txt && \
echo "Configuring jupyter..." && \
jupyter labextension disable "@jupyterlab/apputils-extension:announcements" && \
jupyter labextension enable "@jupyterlab/debugger" && \
jupyter labextension enable "@jupyterlab/toc" && \
jupyter labextension enable "@jupyterlab/execute_time"
#jupyter labextension enable "@jupyterlab/nvdashboard"
#jupyter contrib nbextension install --sys-prefix && \
#jupyter nbextension enable --sys-prefix code_prettify/code_prettify  && \
#jupyter nbextension enable --sys-prefix toc2/main && \
#jupyter nbextension enable --sys-prefix varInspector/main && \
#jupyter nbextension enable --sys-prefix execute_time/ExecuteTime && \
#jupyter nbextension enable --sys-prefix spellchecker/main && \
#jupyter nbextension enable --sys-prefix scratchpad/main && \
#jupyter nbextension enable --sys-prefix collapsible_headings/main && \
#jupyter nbextension enable --sys-prefix codefolding/main
#jupyter nbextension enable --sys-prefix jupyter_resource_usage

FROM mamba-final AS mamba-jupyter-build

USER root

COPY pyenv/jupyter.txt /root/jupyter.txt
RUN mamba env update -v -n ${venv} --file /root/jupyter.txt && \
  rm /root/jupyter.txt && \
  echo "Configuring jupyter..." && \
  jupyter labextension disable "@jupyterlab/apputils-extension:announcements" && \
  jupyter labextension enable "@jupyterlab/debugger" && \
  jupyter labextension enable "@jupyterlab/toc" && \
  jupyter labextension enable "@jupyterlab/execute_time" && \
  #jupyter labextension enable "@jupyterlab/nvdashboard" && \
  mamba clean -itcly 

  #jupyter contrib nbextension install --sys-prefix && \
  #jupyter nbextension enable --sys-prefix code_prettify/code_prettify  && \
  #jupyter nbextension enable --sys-prefix toc2/main && \
  #jupyter nbextension enable --sys-prefix varInspector/main && \
  #jupyter nbextension enable --sys-prefix execute_time/ExecuteTime && \
  #jupyter nbextension enable --sys-prefix spellchecker/main && \
  #jupyter nbextension enable --sys-prefix scratchpad/main && \
  #jupyter nbextension enable --sys-prefix collapsible_headings/main && \
  #jupyter nbextension enable --sys-prefix codefolding/main
  #jupyter nbextension enable --sys-prefix jupyter_resource_usage

FROM jupyter-base AS py-jupyter

COPY --from=py-jupyter-build ${py_dir} ${py_dir}
COPY container-scripts/jn.sh /opt/py/bin/jn
COPY container-scripts/jl.sh /opt/py/bin/jl

USER ${uname}
WORKDIR /home/${uname}

FROM py-jupyter AS py-jupyter-service

USER root

COPY container-scripts/entrypoint.d/ezdev/22-jupyter.sh /opt/container-scripts/entrypoint.d/ezdev/

#RUN echo "source /opt/py/etc/profile.d/conda.sh && conda activate base" >> /opt/container-scripts/entrypoint.d/10-env.sh
#ENTRYPOINT ["/opt/container-scripts/entrypoint.sh"]
#CMD ["bash"]
USER ${uname}
WORKDIR /home/${uname}

FROM mamba-final AS mamba-jupyter

USER root

COPY --from=mamba-jupyter-build ${py_dir} ${py_dir}
COPY container-scripts/jn.sh /opt/py/bin/jn
COPY container-scripts/jl.sh /opt/py/bin/jl

USER ${uname}
WORKDIR /home/${uname}

FROM mamba-jupyter AS mamba-jupyter-service

USER root

COPY container-scripts/entrypoint.d/ezdev/22-jupyter.sh /opt/container-scripts/entrypoint.d/ezdev/

#RUN echo "source /opt/py/etc/profile.d/conda.sh && conda activate base" >> /opt/container-scripts/entrypoint.d/10-env.sh
#ENTRYPOINT ["/opt/container-scripts/entrypoint.sh"]
#CMD ["bash"]
USER ${uname}
WORKDIR /home/${uname}

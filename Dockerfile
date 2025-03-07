# Use multiarch/qemu-user-static for cross-architecture support
FROM ubuntu:22.04 AS base 

# can specify arch during build
# e.g. docker buildx build --platform linux/amd64,linux/arm64 -t wepppy-multiarch --push .


# Set environment variables
ENV TZ=America/Los_Angeles
ENV CXX=x86_64-linux-gnu-g++
ENV CC=x86_64-linux-gnu-gcc
ENV PROJ_LIB=/usr/share/proj/

# Install dependencies and cross-compilation tools
RUN dpkg --add-architecture amd64 && \
    apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    qemu-user-static \
    crossbuild-essential-amd64 \
    g++-x86-64-linux-gnu \
    gcc-x86-64-linux-gnu \
    libc6-dev-amd64-cross \
    cmake \
    meson \
    ninja-build \
    pkg-config \
    sqlite3 \
    zlib1g-dev \
    gfortran \
    libgfortran5 \
    gdal-bin \
    libgdal-dev \
    libyaml-dev \
    git \
    git-lfs \
    ufw \
    gnutls-bin \
    python3-numpy \
    python3-dev \
    python3-pip \
    libpython3-dev \
    libffi-dev \
    vim \
    nano \
    curl \
    wget \
    rsync \
    redis-server \
    supervisor && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Verify that the correct cross-compiler is installed
RUN file /usr/bin/gcc && \
    file /usr/bin/g++ && \
    file /usr/bin/x86_64-linux-gnu-gcc && \
    file /usr/bin/x86_64-linux-gnu-g++

RUN mkdir /worker
WORKDIR /workdir

# Remove distutils-installed blinker to prevent uninstallation errors
RUN rm -rf /usr/lib/python3/dist-packages/blinker* && \
    rm -rf /usr/lib/python3.*/dist-packages/blinker*


# Copy requirements.txt before running pip install
COPY requirements.txt /workdir/

# Install Python dependencies
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

RUN pip install jupyterlab

# Install wepppy
RUN git clone --depth 1 https://github.com/rogerlew/wepppy /workdir/wepppy && \
    cd /workdir/wepppy && git lfs pull

RUN git clone --depth 1 https://github.com/rogerlew/all_your_base /workdir/wepppy/wepppy/all_your_base

# Install rosetta
RUN git clone --depth 1 https://github.com/rogerlew/rosetta /usr/lib/python3/dist-packages/rosetta

# Install wepppy2
RUN git clone --depth 1 https://github.com/wepp-in-the-woods/wepppy2 /workdir/wepppy2

# Install weppcloud2
RUN git clone --depth 1 https://github.com/wepp-in-the-woods/weppcloud2 /workdir/weppcloud2

# Install wepppyo3
RUN git clone --depth 1 https://github.com/wepp-in-the-woods/wepppyo3 /workdir/wepppyo3 && \
    rsync -av --progress /workdir/wepppyo3/release/linux/py310/wepppyo3/ /usr/local/lib/python3.10/dist-packages/wepppyo3/

# Set up OpenTopography API Key
RUN echo "OPENTOPOGRAPHY_API_KEY=" > /workdir/wepppy/wepppy/locales/earth/opentopography/.env

# Ensure Redis is installed
RUN apt-get update && apt-get install -y redis-server

# Modify redis.conf only if it exists
RUN if [ -f /etc/redis/redis.conf ]; then \
    sed -i 's/^daemonize yes/daemonize no/' /etc/redis/redis.conf; \
    fi

# ensure relevant libraries can be found in python
RUN export PYTHONPATH="/workdir/wepppy2:$PYTHONPATH" && export PYTHONPATH="/workdir/wepppy:$PYTHONPATH"

# Expose required ports
EXPOSE 80 5003

VOLUME /geodata

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

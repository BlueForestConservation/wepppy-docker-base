# Use multiarch/qemu-user-static for cross-architecture support
FROM --platform=linux/amd64 ubuntu:22.04 as base

# Set environment variables
ENV TZ=America/Los_Angeles
ENV CXX=x86_64-linux-gnu-g++
ENV CC=x86_64-linux-gnu-gcc
ENV PYTHONPATH=/workdir/wepppy/:/workdir/wepppy2:$PYTHONPATH
ENV PROJ_LIB=/usr/share/proj/
ENV GTIFF_SRS_SOURCE=EPSG

RUN apt-get update && \
    apt-get install -y --no-install-recommends qemu-user-static && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Cross-Build Dependencies for Multiarch
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    software-properties-common \
    crossbuild-essential-amd64 \
    crossbuild-essential-arm64 \
    g++-x86-64-linux-gnu \
    g++-aarch64-linux-gnu \
    gcc-x86-64-linux-gnu \
    gcc-aarch64-linux-gnu \
    libc6-dev-amd64-cross \
    libc6-dev-arm64-cross \
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

# Add UbuntuGIS PPA and Install PROJ Separately
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common gnupg curl && \
    mkdir -p /etc/apt/keyrings && \
    rm -rf /var/lib/apt/lists/lock && \
    while lsof /var/lib/apt/lists/lock; do echo "Waiting for apt lock..."; sleep 2; done && \
    curl -fsSL http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x089EBE08314DF160 | gpg --dearmor -o /etc/apt/keyrings/ubuntugis.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/ubuntugis.gpg] http://ppa.launchpad.net/ubuntugis/ubuntugis-unstable/ubuntu jammy main" | tee /etc/apt/sources.list.d/ubuntugis.list && \
    apt-get update && \
    apt-get install -y proj-bin && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure correct compiler installation
RUN file /usr/bin/gcc && \
    file /usr/bin/g++ && \
    file /usr/bin/x86_64-linux-gnu-gcc && \
    file /usr/bin/x86_64-linux-gnu-g++

# Create work directory
RUN mkdir /worker
WORKDIR /workdir

# Remove distutils-installed blinker to prevent uninstallation errors
RUN rm -rf /usr/lib/python3/dist-packages/blinker* && \
    rm -rf /usr/lib/python3.*/dist-packages/blinker*

# Copy requirements.txt before running pip install
COPY requirements.txt /workdir/

# Install Python dependencies with fixes for NumPy and Paramiko
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --upgrade --force-reinstall "numpy<2"

# Upgrade PROJ database to avoid CRS warnings
RUN add-apt-repository ppa:ubuntugis/ubuntugis-unstable && \
    apt-get update && \
    apt-get install -y proj-bin

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

# Configure and start Redis correctly
RUN sed -i 's/daemonize yes/daemonize no/g' /etc/redis/redis.conf && \
    echo "supervisord -c /etc/supervisor/conf.d/supervisord.conf" > /workdir/start.sh && \
    chmod +x /workdir/start.sh

# Expose required ports
EXPOSE 80 5003

VOLUME /geodata

# Copy supervisor config
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Start services
CMD ["/workdir/start.sh"]

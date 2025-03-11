
# Multi-Architecture Docker Setup for wepppy

## Installation and Setup
Note this repo is orginally forked and modified from [here](https://github.com/rogerlew/wepppy-docker-base)

### 1. Install Docker

Download Docker from the [official Docker website](https://www.docker.com/) and install it.

### 2. Setup Docker Buildx (for ARM-based Macs)

If you're using an ARM-based Mac (M1 or newer), enable Docker Buildx:

```bash
docker buildx create --name mybuilder --use
docker buildx inspect --bootstrap
```

### 3. Clone Repository

Clone this repository and navigate into it:

```bash
git clone <repository-url>
cd <repository-directory>
```

## Building Docker Image

- **AMD64 (Intel)**:

```bash
docker build -t wepppy .
```

- **ARM64 (Apple Silicon)**:

```bash
docker buildx build --platform linux/amd64 -t wepppy --load .
```

## Running Docker Container

- **AMD64 (Intel)**:

```bash
docker run -p 8888:8888 --name wepppy-container wepppy
```

- **ARM64 (forcing AMD64 emulation)**:

```bash
docker run --platform linux/amd64 -p 8888:8888 --name wepppy-container wepppy
```

## Jupyter Lab with Volume Mount

Run Jupyter Lab with a volume mount:

```bash
docker run --platform linux/amd64 -p 8888:8888 --name wepppy-container -v $(pwd)/volume_to_mount:/geodata wepppy jupyter lab --NotebookApp.notebook_dir=/ --ip=0.0.0.0 --allow-root
```

Inside Jupyter shell, start Redis to enable wepppy:

```bash
!redis-server --daemonize yes
```

Access Jupyter Lab via https token in shell.

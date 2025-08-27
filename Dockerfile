# BUILDER STAGE
# Use a Python image with uv pre-installed
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim as builder

# Install ANTs
RUN apt-get update && \
    apt-get install -y wget unzip && \
    wget -O ants.zip https://github.com/ANTsX/ANTs/releases/download/v2.6.2/ants-2.6.2-ubuntu-22.04-X64-gcc.zip && \
    unzip ants.zip && \
    rm ants.zip

# Install greedy in /itksnap/greedy
RUN wget -O greedy.tar.gz https://sourceforge.net/projects/greedy-reg/files/Nightly/greedy-nightly-Linux-gcc64.tar.gz/download && \
    mkdir -p /itksnap/greedy && \
    tar -xzf greedy.tar.gz -C /itksnap/greedy --strip-components=1 && \
    rm greedy.tar.gz

# Install c3d tools in /itksnap/c3d
RUN wget -O /tmp/c3d.tar.gz http://downloads.sourceforge.net/project/c3d/c3d/Nightly/c3d-nightly-Linux-gcc64.tar.gz && \
    mkdir -p /itksnap/c3d && \
    tar -xzf /tmp/c3d.tar.gz -C /itksnap/c3d --strip-components=1 && \
    rm /tmp/c3d.tar.gz

# Install Conda from Miniforge
RUN wget -O /tmp/miniforge.sh https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh && \
    bash /tmp/miniforge.sh -b -p /opt/conda && \
    rm /tmp/miniforge.sh

# Install FSL
ENV FSL_CONDA_CHANNEL="https://fsl.fmrib.ox.ac.uk/fsldownloads/fslconda/public"
RUN /opt/conda/bin/conda install -n base -y -c $FSL_CONDA_CHANNEL -c conda-forge \
    tini \
    fsl-utils \
    fsl-avwutils \
    fsl-flirt && \
    /opt/conda/bin/conda clean -afy



# RUNNER STAGE
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim as runner

COPY --from=builder /ants-2.6.2/bin/antsRegistration /ants-2.6.2/bin/antsRegistration
COPY --from=builder /ants-2.6.2/bin/antsApplyTransforms /ants-2.6.2/bin/antsApplyTransforms
COPY --from=builder /itksnap/greedy /itksnap/greedy
COPY --from=builder /itksnap/c3d /itksnap/c3d
COPY --from=builder /opt/conda /opt/conda

ENV PATH="/ants-2.6.2/bin:$PATH"
ENV PATH="/itksnap/greedy/bin:$PATH"
ENV PATH="/itksnap/c3d/bin:$PATH"
ENV PATH="/opt/conda/bin:$PATH"
ENV FSLDIR="/opt/conda"
    
# Install the project into `/app`
WORKDIR /app

# Enable bytecode compilation
ENV UV_COMPILE_BYTECODE=1
# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy
# Ensure installed tools can be executed out of the box
ENV UV_TOOL_BIN_DIR=/usr/local/bin

# Install the project's dependencies using the lockfile and settings
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev

# Then, add the rest of the project source code and install it
# Installing separately from its dependencies allows optimal layer caching
COPY . /app
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev
RUN /opt/conda/bin/pip install -r /app/requirements.txt

# Place executables in the environment at the front of the path
ENV PATH="/app/.venv/bin:$PATH"

RUN mkdir -p data
RUN chmod +x /app/main.sh

ENTRYPOINT ["/app/main.sh"]
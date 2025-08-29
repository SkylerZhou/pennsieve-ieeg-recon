# BUILDER STAGE
# Use a Python image with uv pre-installed
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS builder

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
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS runner

# ---- Revised: for debugging
#RUN apt-get update && \
#    apt-get install -y --no-install-recommends \
#    libx11-6 \
#    libgomp1 \
#    libgcc-s1 \
#    libstdc++6 \
#    libc6 \
#    libglib2.0-0 \
#    libsm6 \
#    libice6 \
#    libxext6 \
#    libxrender1 \
#    libfontconfig1 \
#    libgtk-3-0 \
#    libc6-dev \
#    file \
#    && rm -rf /var/lib/apt/lists/*
# ---- Revised finished 

COPY --from=builder /ants-2.6.2/bin/antsRegistration /ants-2.6.2/bin/antsRegistration
COPY --from=builder /ants-2.6.2/bin/antsApplyTransforms /ants-2.6.2/bin/antsApplyTransforms
COPY --from=builder /itksnap/greedy /itksnap/greedy

# ---- Revised: for debugging /itksnap/c3d_affine_tool failed in MODULE 2
COPY --from=builder /itksnap/c3d /itksnap/c3d
RUN mkdir -p /itksnap/bin && \
    ln -sf /itksnap/greedy/bin/greedy           /itksnap/bin/greedy && \
    ln -sf /itksnap/c3d/bin/c3d                 /itksnap/bin/c3d && \
    ln -sf /itksnap/c3d/bin/c3d_affine_tool     /itksnap/bin/c3d_affine_tool
# ---- Revised finished 

COPY --from=builder /opt/conda /opt/conda


# ---- Revised: for testing greedy dir for MODULE 2
# After extracting: rename the extracted dir to avoid path clash
RUN mv /itksnap/greedy /itksnap/greedy_pkg
# create canonical /itksnap/bin
RUN mkdir -p /itksnap/bin
# point both styles to the real binary
RUN ln -sf /itksnap/greedy_pkg/bin/greedy /itksnap/bin/greedy && \
    ln -sf /itksnap/greedy_pkg/bin/greedy /itksnap/greedy
ENV PATH="/itksnap/bin:/ants-2.6.2/bin:/opt/conda/bin:${PATH}"
ENV ITKSNAP_DIR="/itksnap/bin"
# ---- Revised finished 

# ---- Revised: for debugging Module 3 error
ENV FREESURFER_HOME=/service/doc/freesurfer
ENV SUBJECTS_DIR=/service/doc/freesurfer/subjects
# ---- Revised finished 


ENV PATH="/ants-2.6.2/bin:$PATH"
ENV PATH="/itksnap/greedy/bin:$PATH"
ENV PATH="/itksnap/c3d/bin:$PATH"
ENV PATH="/opt/conda/bin:$PATH"
ENV FSLDIR="/opt/conda"
ENV FSL_DIR="/opt/conda"
ENV FSL_OUTPUT_TYPE="NIFTI_GZ"
    

# Install the project into `/service`
WORKDIR /service          

# Enable bytecode compilation
ENV UV_COMPILE_BYTECODE=1
# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy
# Ensure installed tools can be executed out of the box
ENV UV_TOOL_BIN_DIR=/usr/local/bin

# Edited out for debugging:
# Install the project's dependencies using the lockfile and settings
#RUN --mount=type=cache,target=/root/.cache/uv \
#    --mount=type=bind,source=uv.lock,target=uv.lock \
#    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
#    uv sync --locked --no-install-project --no-dev
#COPY pyproject.toml uv.lock /service/
#RUN uv sync --locked --no-dev 
COPY requirements.txt /service/requirements.txt
RUN pip install -r /service/requirements.txt

# Then, add the rest of the project source code and install it
# Installing separately from its dependencies allows optimal layer caching
COPY . /service
#RUN --mount=type=cache,target=/root/.cache/uv \
#    uv sync --locked --no-dev

# Place executables in the environment at the front of the path
ENV PATH="/service/.venv/bin:$PATH"

RUN mkdir -p data
RUN chmod +x /service/main.sh

ENTRYPOINT ["/service/main.sh"]
# ---- single builder/runner hybrid, simple & robust ----
FROM python:3.9-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive PYTHONUNBUFFERED=1

# OS libs + download tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget unzip ca-certificates curl tar xz-utils \
    libx11-6 libgomp1 libgcc-s1 libstdc++6 libc6 libglib2.0-0 \
    libsm6 libice6 libxext6 libxrender1 libfontconfig1 libgtk-3-0 \
    && rm -rf /var/lib/apt/lists/*

# ANTs (prebuilt x86_64 zip)
RUN wget -O /tmp/ants.zip https://github.com/ANTsX/ANTs/releases/download/v2.6.2/ants-2.6.2-ubuntu-22.04-X64-gcc.zip && \
    unzip /tmp/ants.zip -d / && rm -f /tmp/ants.zip

# greedy (ITK-SNAP)
RUN wget -O /tmp/greedy.tar.gz https://sourceforge.net/projects/greedy-reg/files/Nightly/greedy-nightly-Linux-gcc64.tar.gz/download && \
    mkdir -p /itksnap/greedy && \
    tar -xzf /tmp/greedy.tar.gz -C /itksnap/greedy --strip-components=1 && \
    rm -f /tmp/greedy.tar.gz

# c3d (ITK-SNAP tools)
RUN wget -O /tmp/c3d.tar.gz http://downloads.sourceforge.net/project/c3d/c3d/Nightly/c3d-nightly-Linux-gcc64.tar.gz && \
    mkdir -p /itksnap/c3d && \
    tar -xzf /tmp/c3d.tar.gz -C /itksnap/c3d --strip-components=1 && \
    rm -f /tmp/c3d.tar.gz

# Miniforge (use conda base for FSL + python runtime)
RUN wget -O /tmp/miniforge.sh https://github.com/conda-forge/miniforge/releases/download/24.7.1-2/Miniforge3-Linux-x86_64.sh && \
    bash /tmp/miniforge.sh -b -p /opt/conda && rm -f /tmp/miniforge.sh
ENV PATH=/opt/conda/bin:$PATH
ENV FSL_CONDA_CHANNEL="https://fsl.fmrib.ox.ac.uk/fsldownloads/fslconda/public"

# FSL minimal tools
RUN conda install -n base -y -c $FSL_CONDA_CHANNEL -c conda-forge \
      tini fsl-utils fsl-avwutils fsl-flirt && \
    conda clean -afy

# ITK-SNAP canonical bin + symlinks (pipeline expects $ITKSNAP_DIR/greedy & c3d_affine_tool)
RUN mkdir -p /itksnap/bin && \
    ln -sf /itksnap/greedy/bin/greedy       /itksnap/bin/greedy && \
    ln -sf /itksnap/c3d/bin/c3d             /itksnap/bin/c3d && \
    ln -sf /itksnap/c3d/bin/c3d_affine_tool /itksnap/bin/c3d_affine_tool

# Tool envs
ENV ITKSNAP_DIR=/itksnap/bin \
    FSLDIR=/opt/conda \
    FSL_DIR=/opt/conda \
    FSL_OUTPUT_TYPE=NIFTI_GZ \
    PATH=/itksnap/bin:/ants-2.6.2/bin:/opt/conda/bin:$PATH

# Install your Python deps into system Python 3.9 (NOT conda)
WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN python -m pip install --upgrade pip setuptools wheel
RUN pip install --no-cache-dir -r /app/requirements.txt

# Verify imports at build time (optional but helpful)
RUN python - <<'PY'
import sys
print("Using:", sys.executable)
import IPython, pandas, numpy, nibabel, scipy, dotenv, trimesh, nilearn, matplotlib, plotly
print("All core imports OK")
PY

# Now copy your code
COPY . /app

# Make entrypoint runnable
RUN chmod +x /app/main.sh
ENTRYPOINT ["/app/main.sh"]
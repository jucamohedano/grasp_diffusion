FROM pytorch/torchserve:0.3.0-cpu

COPY requirements.txt requirements.txt
COPY new_environment.yml new_environment.yml
COPY Miniconda3-latest-Linux-x86_64.sh Miniconda3-latest-Linux-x86_64.sh

USER root
RUN printf "\nservice_envelope=json" >> /home/model-server/config.properties

# install deps
RUN apt-get update && apt-get -y upgrade \
  && apt-get install -y --no-install-recommends \
    git \
    wget \
    g++ \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
ENV PATH="/root/miniconda3/bin:${PATH}"
ARG PATH="/root/miniconda3/bin:${PATH}"
# RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
RUN mkdir /root/.conda \
    && bash Miniconda3-latest-Linux-x86_64.sh -b \
    && rm -f Miniconda3-latest-Linux-x86_64.sh \
    && echo "Running $(conda --version)"
RUN conda init bash && \
    . /home/model-server/.bashrc && \
    conda update conda && \
    conda env create -f new_environment.yml && \
    conda activate se3dif_env && \
    echo 'conda activate se3dif_env \n' >> /home/model-server/.bashrc

RUN git clone https://github.com/TheCamusean/mesh_to_sdf.git && \
    cd mesh_to_sdf && \
    pip install -e . \
    cd .. && git clone https://github.com/facebookresearch/theseus.git && \
    cd theseus && \
    pip install -e .


USER model-server

RUN torch-model-archiver \
  --model-name=mnist \
  --version=1.0 \
  --model-file=/home/model-server/mnist.py \
  --serialized-file=/home/model-server/mnist_cnn.pt \
  --handler=/home/model-server/mnist_handler.py \
  --export-path=/home/model-server/model-store

CMD ["torchserve", \
     "--start", \
     "--ts-config=/home/model-server/config.properties", \
     "--models", \
     "mnist=mnist.mar"]
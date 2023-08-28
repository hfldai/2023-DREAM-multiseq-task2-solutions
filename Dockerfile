FROM nvidia/cuda:11.1.1-cudnn8-runtime-ubuntu20.04

RUN apt-get update && apt-get install -y software-properties-common && apt-get install -y build-essential
RUN add-apt-repository ppa:deadsnakes/ppa

## essentials for build pkgs
RUN apt update && apt install -y git libz-dev vim wget curl jq bzip2 make sed

## install bedtools
RUN wget -O /usr/local/bin/bedtools https://github.com/arq5x/bedtools2/releases/download/v2.30.0/bedtools.static.binary && \
  chmod a+x /usr/local/bin/bedtools && \
  rm -rf /var/lib/apt/lists/*

## install samtools
RUN  apt-get update \
     && apt-get install -y libncurses-dev libbz2-dev liblzma-dev zlib1g-dev \
     && rm -rf /var/lib/apt/lists/*
RUN wget -O samtools-1.16.1.tar.bz2 https://sourceforge.net/projects/samtools/files/samtools/1.16/samtools-1.16.1.tar.bz2/download && \
    tar xvjf samtools-1.16.1.tar.bz2 && \
    cd samtools-1.16.1 && \ 
    ./configure && \
    make && \
    make install
RUN export PATH="$PATH:samtools-1.16.1"

## install python3.11 and essentials
WORKDIR /usr/src
RUN apt-get update && apt-get install -y python3.11
RUN apt-get update && apt-get install -y python3 python3-pip python3-dev gcc parallel tree
RUN ln -nsf /usr/bin/python3.11 /usr/bin/python
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
RUN export PYTHONPATH="/usr/local/bin:$PYTHONPATH:/usr/local/lib/python3.11/site-packages"
RUN python3 -m pip install --upgrade pip
#RUN echo 'will cite' | parallel --citation || true
RUN export PATH="/usr/local/bin:/usr/bin:$PATH"
RUN export PYTHONUSERBASE="/usr/local/bin:$PYTHONUSERBASE"

## install python pkg from github: atacworks
RUN git clone --recursive https://github.com/clara-genomics/AtacWorks.git
## do not restrict versions in requirements
RUN sed -i 's/~=[0-9\.]\+$//g' AtacWorks/requirements.txt 
## change the value of gen_bigwig to False
RUN sed -i 's/gen_bigwig: True/gen_bigwig: False/g' AtacWorks/configs/infer_config.yaml
## solve incompatible python version issues
RUN sed -i 's/append/_append/g' AtacWorks/atacworks/dl4atac/utils.py 
RUN sed -i 's/from collections import Iterable, OrderedDict/from collections import OrderedDict\nfrom collections.abc import Iterable/g' AtacWorks/atacworks/dl4atac/losses.py
RUN cd AtacWorks && python3 -m pip install -r requirements.txt && python3 -m pip install .

## install python pkg: deepTools
WORKDIR /usr/src
RUN python3 -m pip install deepTools

## copy atacworks pre-trained model (on manually further-downsampled sample data) & script for extracting peaks & script for running model
COPY model_best.pth.tar /model_best.pth.tar
COPY peaksummary_using_bedgraph.py /peaksummary_using_bedgraph.py
COPY run_model.sh /run_model.sh

# run model: for atacworks, using the default threshold 0.5 to call peaks
ENTRYPOINT ["bash", "/run_model.sh", "/input", "/output", "/model.pth.tar", "/peaksummary_using_bedgraph.py", "0.5"]

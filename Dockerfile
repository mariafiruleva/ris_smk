# https://hub.docker.com/r/continuumio/miniconda3
FROM continuumio/miniconda3:4.9.2

#  $ docker build . -t mfiruleva/snakemake
#  $ docker run --rm -it mfiruleva/snakemake /bin/bash
#  $ docker push mfiruleva/snakemake
MAINTAINER Maria Firulyova, ITMO CT Lab <mmfiruleva@gmail.com>

# Resolve issue with undefined user name for LDAP users, e.g remove warnings
#  group..
#  username..
RUN apt-get update && \
 apt-get upgrade -y && \
 apt-get install -y --no-install-recommends libnss-sss

# Solve locale issues when running bash.
#   /bin/bash: warning: setlocale: LC_ALL: cannot change locale (en_US.UTF-8)
#
# It breaks conda version check in snakemake:
RUN apt-get clean && apt-get update && apt-get install -y locales && \
    echo "LC_ALL=en_US.UTF-8" >> /etc/environment  && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen  && \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf  && \
    locale-gen en_US.UTF-8

# JAVA 8 missing fonts workaround:
# see https://bugs.debian.org/793210
# and https://github.com/docker-library/java/issues/46#issuecomment-119026586
# P.S: our java comes from conda, seems the same issue
RUN apt-get update && apt-get install -y --no-install-recommends libfontconfig1

#  GNU/GCC compiler and related tools (such as make, debugger, man pages) collection
RUN apt-get update && apt-get install -y build-essential autoconf automake

# collection of debian utility tools, e.g. 'column', etc
RUN apt-get update && apt-get install -y bsdmainutils

# Install additional tools: ps, htop, vim, mc
RUN apt-get update && apt-get install -y procps htop vim mc nano tmux screen tree

RUN apt-get update && apt-get install -y locate

# --------------------------------------------------------
# Additional tools / libs for bioinformatics:

#-----------
## Install CellRanger & bamtofastq

RUN mkdir -p /opt && cd /opt && \
   wget -O cellranger-6.1.1.tar.gz "https://cf.10xgenomics.com/releases/cell-vdj/cellranger-6.1.1.tar.gz?Expires=1633388746&Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiaHR0cHM6Ly9jZi4xMHhnZW5vbWljcy5jb20vcmVsZWFzZXMvY2VsbC12ZGovY2VsbHJhbmdlci02LjEuMS50YXIuZ3oiLCJDb25kaXRpb24iOnsiRGF0ZUxlc3NUaGFuIjp7IkFXUzpFcG9jaFRpbWUiOjE2MzMzODg3NDZ9fX1dfQ__&Signature=SxhbvPf3l8bOcRh65f-uDH63dPz8pccmOF-TSRwvybE6fX36D6vSaMB2hvNDcsWQFi7q5UBjHZYrdvKzzAamlV8lHaMGaL2H3uP3-2tDYr-ScBJHoMo~MKAiKQACD6TYxbyqyhd994g~IPpB8Rfioy2ft0~PhgKd3Y-aHngVZeJFJ4WoueCa56knxzTGm9dO6urYRBXKCxs1WlUhLrUBZNkp-HgLXFqfi7ngqBJnDDhJzQtdnVXAi7sqsrP9Hys5PvWxbzTXc1ymjLhJFl50cxpn14F7Ckg0SakAiAvR3K3KO54iaK8pfc6AeGuPZ~fOeM3nkz-8Ye69miiTzx-YTQ__&Key-Pair-Id=APKAI7S6A5RYOXBWRPDA" && \
   tar -xzvf cellranger-6.1.1.tar.gz  && \
   rm -rf cellranger-6.1.1.tar.gz && \
   wget https://cf.10xgenomics.com/misc/bamtofastq-1.3.2 && \
   chmod 700 bamtofastq-1.3.2

ENV PATH /opt/cellranger-6.1.1/cellranger:$PATH
ENV PATH /opt/bamtofastq-1.3.2:$PATH

# The GNU Scientific Library
RUN apt-get update && apt-get install -y libgsl-dev

#-----------

# Install HTSlib: https://github.com/samtools/htslib
RUN apt-get update && apt-get install -y perl zlib1g-dev libbz2-dev liblzma-dev libcurl4-gnutls-dev libssl-dev
#RUN apt-get update && apt-get install -ay libbz2-dev zlib1g-dev libncurses5-dev libncursesw5-dev liblzma-dev
RUN cd /usr/bin && \
    wget https://github.com/samtools/htslib/releases/download/1.11/htslib-1.11.tar.bz2 && \
    tar -vxjf htslib-1.11.tar.bz2 && cd /usr/bin/htslib-1.11 && \
    autoreconf && \
    ./configure && make && make install && \
    rm -rf /usr/bin/htslib-1.11

# ---------
# Install xvfb & Co for plot.ly (orca) & Git
# RUN apt-get install -y software-properties-common
RUN apt-get update && apt-get install -y git xvfb libgtk2.0-0 libxtst-dev libxss1 gconf-gsettings-backend libnss3 libasound2

# --------------------------------------------------------
# --------------------------------------------------------
# --------------------------------------------------------

# Cleanup apt caches
RUN rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------
# --------------------------------------------------------
# --------------------------------------------------------

# Install snakemake and other packages
COPY environment.yaml /root/environment.yaml
RUN conda update  --yes -n base -c defaults conda setuptools
RUN conda env update -n base --file /root/environment.yaml
RUN conda clean   --yes --all
RUN rm /root/environment.yaml

# Install conga (https://github.com/phbradley/conga)

RUN cd /usr/bin && \
    git clone https://github.com/phbradley/conga.git && \
    cd conga/tcrdist_cpp && \
    make && \
    ./configure && make && make install && \
    rm -rf /usr/bin/htslib-1.11

# Install R packages (unavailable / old version on conda): MiQC, SeuratWrappers, SeuratData, Phantasusl SCNPrep, flexmix

RUN R -e 'remotes::install_github("greenelab/miQC", build_vignettes = F)' && \
    R -e 'remotes::install_github("satijalab/seurat-wrappers")' && \
    R -e 'devtools::install_github("satijalab/seurat-data")' && \
    R -e 'BiocManager::install("phantasus")' && \
    R -e 'devtools::install_github("ctlab/SCNPrep")' && \
    R -e 'install.packages("flexmix")'


# Fix PATH and profile when running in LSF cluster
RUN echo "PATH=/opt/conda/condabin:/opt/conda/bin:\$PATH" > /opt/conda/.bashrc && \
    cat /root/.bashrc >> /opt/conda/.bashrc

# Simulate `conda init` and write config to global bash config. It is needed for docker containers
# which are launched with custom user folder and thus lack of original ~/.bashrc settings
RUN echo "export  PATH=/opt/conda/condabin:\$PATH" > /etc/bash.bashrc && \
    echo "# >>> conda initialize >>>" >> /etc/bash.bashrc && \
    echo "__conda_setup=\"\$('/opt/conda/bin/conda' 'shell.bash' 'hook' 2> /dev/null)\"" >> /etc/bash.bashrc && \
    echo "eval \"\$__conda_setup\"" >> /etc/bash.bashrc && \
    echo "unset __conda_setup" >> /etc/bash.bashrc && \
    echo "# <<< conda initialize <<<" >> /etc/bash.bashrc

# Wrapper to pass custom source file before docker command execution, e.g. could be used
# to pass some env variables or source other config files
COPY cmd_wrapper.sh /usr/bin
RUN chmod a+x /usr/bin/cmd_wrapper.sh

# Could be overriden, e.g. run: docker run -it --entrypoint /bin/bash biolabs/snakemake
ENTRYPOINT [ "/usr/bin/cmd_wrapper.sh" ]

# E.g.: use w/o additional scripts to source:
#CMD ["/bin/bash", "-l"]

# seems enough is 'use-source  /etc/bash.bashrc'

# E.g.: Specify 1 or multiple times 'use-source' with script to source, e.g.
CMD ["use-source", "/opt/conda/.bashrc", "/bin/bash", "-l"]
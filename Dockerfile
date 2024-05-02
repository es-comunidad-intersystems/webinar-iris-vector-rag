ARG IMAGE=intersystemsdc/iris-community:latest
FROM $IMAGE

USER root

# create directory to copy files into image
WORKDIR /opt/irisapp
RUN chown -R irisowner:irisowner /opt/irisapp

# install tools
RUN apt-get update && apt-get install -y \
  python3-pip \
  && rm -rf /var/lib/apt/lists/*

USER irisowner

# copy files to image
WORKDIR /opt/irisapp
RUN mkdir -p /opt/irisapp/db
COPY --chown=irisowner:irisowner iris.script iris.script
COPY --chown=irisowner:irisowner src src
COPY --chown=irisowner:irisowner install install
COPY --chown=irisowner:irisowner requirements.txt requirements.txt

# install python libraries
RUN pip3 install --target /usr/irissys/mgr/python/ -r requirements.txt

# run iris.script
RUN iris start IRIS \
    && iris session IRIS < /opt/irisapp/iris.script \
    && iris stop IRIS quietly
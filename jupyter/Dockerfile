FROM jupyter/minimal-notebook

COPY requirements.txt "${HOME}"

# install IRIS DBAPI driver
#RUN wget https://raw.githubusercontent.com/intersystems-community/iris-driver-distribution/main/DB-API/intersystems_irispython-3.2.0-py3-none-any.whl
#RUN pip install intersystems_irispython-3.2.0-py3-none-any.whl

# install python packages
RUN pip install -r requirements.txt
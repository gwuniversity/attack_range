FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive 

RUN apt update && apt upgrade -y
RUN apt-get install -y software-properties-common
RUN apt update
RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt update
RUN apt install -y python3.12

RUN apt-get install -y git unzip python3-pip curl vim apt-transport-https ca-certificates gnupg curl

RUN curl -s https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip -o terraform.zip && \
         unzip terraform.zip && \
         mv terraform /usr/local/bin/ && \
	 rm -rf /terraform.zip

RUN echo 'alias python=python3.12' >> ~/.bashrc

RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3.12 get-pip.py && \
    rm get-pip.py
RUN python3.12 -m pip install --upgrade setuptools wheel

RUN python3.12 -m pip install --upgrade pip

RUN python3.12 -m pip install --upgrade awscli azure-cli

RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && apt-get update -y && apt-get install google-cloud-cli -y

RUN git clone https://github.com/splunk/attack_range.git

WORKDIR /attack_range

RUN python3.12 -m pip install -r requirements.txt


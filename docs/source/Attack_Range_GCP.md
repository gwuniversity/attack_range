# Attack Range GCP

## Docker
We built a docker image which you can use to build and run the attack range. The image includes all needed binaries. 
````bash
docker pull splunk/attack_range
docker run -it splunk/attack_range
gcloud auth application-default login
python attack_range.py configure
````

## MacOS
Clone attack_range git repo to local machine:
````bash
git clone https://github.com/splunk/attack_range.git
cd attack_range
````

Install and configure Terraform:
````bash
brew update
brew install terraform
cd terraform/gcp && terraform init && cd ../..
````

Install the GCP CLI by follwoing this [guide](https://cloud.google.com/sdk/docs/install-sdk).

Install and run Poetry:
````bash
curl -sSL https://install.python-poetry.org/ | python -
poetry shell
poetry install
````

Configure Attack Range:
````bash
python attack_range.py configure
````

Once the configuration is complete, you can proceed to build and control your range [here](Control_Attack_Range.md)

## Linux
Install the required packages:
````bash
apt-get update
apt-get install -y python3.10 git unzip python3-pip curl
````

Install and configure Terraform:
````bash
curl -s https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip -o terraform.zip && \
unzip terraform.zip && \
mv terraform /usr/local/bin/
````

Clone attack_range git repo to local machine:
````bash
git clone https://github.com/splunk/attack_range.git
cd attack_range
````

Install the GCP CLI by follwoing this [guide](https://cloud.google.com/sdk/docs/install-sdk).

Install and run Poetry:
````bash
curl -sSL https://install.python-poetry.org/ | python -
poetry shell
poetry install
````

````bash
python attack_range.py configure
````

Once the configuration is complete, you can proceed to build and control your range [here](Control_Attack_Range.md)

## Windows

We recommend using the Windows Subsystem for Linux (WSL). You can find a tutorial [here](https://docs.microsoft.com/en-us/windows/wsl/install). After installing WSL, you can follow the steps described in the [Linux section](#linux).

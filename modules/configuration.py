from Crypto.PublicKey import RSA
from pathlib import Path
from botocore.config import Config
import sys
import argparse
import urllib.request
import configparser
import random
import string
import boto3
import getpass
import time
import questionary
import os
import yaml
from typing import Dict, List, Optional, Tuple


# need to be retrieved from config
VERSION = "3.0.0"


class ConfigurationManager:
    """Manages the configuration of an attack range system."""

    def __init__(self, config_path: str):
        """Initialize the configuration manager.

        Args:
            config_path: Path to the configuration file
        """
        self.config_path = Path(config_path)
        self.configuration: Dict = {}
        self.external_ip: str = ""

    def _get_random_password(self) -> str:
        """Generate a secure random password.

        Returns:
            A randomly generated password string
        """
        random_source = string.ascii_letters + string.digits
        password = random.choice(string.ascii_lowercase)
        password += random.choice(string.ascii_uppercase)
        password += random.choice(string.digits)

        for _ in range(16):
            password += random.choice(random_source)

        password_list = list(password)
        random.SystemRandom().shuffle(password_list)
        return "".join(password_list)

    def _get_external_ip(self) -> str:
        """Get the external IP address of the current machine.

        Returns:
            The external IP address as a string
        """
        try:
            return urllib.request.urlopen("https://v4.ident.me").read().decode("utf8")
        except Exception:
            print("WARNING: Unable to determine the public IP")
            return ""

    def _create_key_pair_aws(self, region: str) -> str:
        """Create an AWS key pair.

        Args:
            region: AWS region to create the key pair in

        Returns:
            Name of the created key pair
        """
        aws_session = boto3.Session()
        client = aws_session.client("ec2", region_name=region)

        epoch_time = str(int(time.time()))
        ssh_key_name = f"{getpass.getuser()}-{epoch_time[-5:]}.key"

        response = client.create_key_pair(KeyType="rsa", KeyName=str(ssh_key_name)[:-4])
        with open(ssh_key_name, "w") as ssh_key:
            ssh_key.write(response["KeyMaterial"])
        os.chmod(ssh_key_name, 0o600)
        return ssh_key_name

    def _create_key_pair_azure(self) -> Tuple[str, str]:
        """Create Azure key pair.

        Returns:
            Tuple of (private_key_path, public_key_path)
        """
        epoch_time = str(int(time.time()))
        key = RSA.generate(2048)

        priv_key_name = f"{getpass.getuser()}-{epoch_time[-5:]}.key"
        pub_key_name = f"{getpass.getuser()}-{epoch_time[-5:]}.pub"

        with open(priv_key_name, "wb") as content_file:
            os.chmod(priv_key_name, 0o600)
            content_file.write(key.exportKey("PEM"))

        pubkey = key.publickey()
        with open(pub_key_name, "wb") as content_file:
            content_file.write(pubkey.exportKey("OpenSSH"))

        return priv_key_name, pub_key_name

    def _get_generated_keys(self) -> Tuple[str, str]:
        """Get existing key pairs in the current directory.

        Returns:
            Tuple of (private_key_path, public_key_path)
        """
        priv_keys = []
        pub_keys = []

        for file in os.listdir("."):
            if file.endswith(".key"):
                priv_keys.append(Path(file).resolve())
            if file.endswith(".pub"):
                pub_keys.append(Path(file).resolve())

        priv_key = priv_keys[0] if priv_keys else ""
        pub_key = pub_keys[0] if pub_keys else ""

        return priv_key, pub_key

    def _check_for_generated_keys(self, answers=None) -> bool:
        """Check if there are any generated keys in the current directory.

        Args:
            answers: Optional questionary answers dict (unused)

        Returns:
            True if keys exist, False otherwise
        """
        return any(file.endswith(".key") for file in os.listdir("."))

    def _configure_cloud_provider(self) -> None:
        """Configure the cloud provider settings."""
        questions = [
            {
                "type": "select",
                "message": "Select cloud provider",
                "name": "provider",
                "choices": ["aws", "azure", "gcp"],
                "default": "aws",
            },
            {
                "type": "input",
                "message": "Enter Azure subscription id",
                "name": "azure_subscription_id",
                "when": lambda answers: answers["provider"] == "azure",
            },
            {
                "type": "input",
                "message": "Enter GCP project ID",
                "name": "gcp_project_id",
                "when": lambda answers: answers["provider"] == "gcp",
            },
            {
                "type": "input",
                "message": "Enter a master password for your attack_range",
                "name": "attack_range_password",
                "default": self._get_random_password(),
            },
        ]

        answers = questionary.prompt(questions)
        self.configuration["general"] = {
            "cloud_provider": answers["provider"],
            "attack_range_password": answers["attack_range_password"],
        }

        self.configuration[answers["provider"]] = {}

        if answers["provider"] == "aws":
            aws_session = boto3.Session()
            if aws_session.region_name:
                self.configuration["aws"]["region"] = aws_session.region_name
            else:
                print("ERROR: AWS region not configured, please run `aws configure`")
                sys.exit(1)

        elif answers["provider"] == "azure":
            if "azure_subscription_id" in answers:
                self.configuration["azure"]["subscription_id"] = answers[
                    "azure_subscription_id"
                ]
            else:
                print("ERROR: Azure subscription ID is required")
                sys.exit(1)

        elif answers["provider"] == "gcp":
            if "gcp_project_id" in answers:
                self.configuration["gcp"]["project_id"] = answers["gcp_project_id"]
            else:
                print("ERROR: GCP project ID is required")
                sys.exit(1)

    def _configure_ssh_keys(self) -> None:
        """Configure SSH keys for the attack range."""
        if self.configuration["general"]["cloud_provider"] == "local":
            return

        priv_key, pub_key = self._get_generated_keys()

        questions = [
            {
                "type": "confirm",
                "message": f"Detected existing key in {priv_key}, would you like to use it",
                "name": "reuse_keys",
                "default": True,
                "when": self._check_for_generated_keys,
            },
            {
                "type": "confirm",
                "message": "Generate a new ssh key pair for this range",
                "name": "new_key_pair",
                "default": True,
                "when": lambda answers: not answers.get("reuse_keys", False),
            },
        ]

        answers = questionary.prompt(questions)

        if answers.get("reuse_keys"):
            priv_key_name = os.path.basename(os.path.normpath(priv_key))
            self.configuration["general"]["key_name"] = str(priv_key_name)[:-4]

            provider = self.configuration["general"]["cloud_provider"]
            self.configuration[provider]["private_key_path"] = str(priv_key)
            if provider in ["azure", "gcp"]:
                self.configuration[provider]["public_key_path"] = str(pub_key)

            print(f"> Included ssh private key: {priv_key}")

        elif answers.get("new_key_pair"):
            provider = self.configuration["general"]["cloud_provider"]
            if provider == "aws":
                new_key_name = self._create_key_pair_aws(
                    self.configuration["aws"]["region"]
                )
                new_key_path = Path(new_key_name).resolve()
                self.configuration["general"]["key_name"] = new_key_name[:-4]
                self.configuration["aws"]["private_key_path"] = str(new_key_path)
                print(f"> New AWS ssh created: {new_key_path}")

            elif provider == "azure":
                priv_key_name, pub_key_name = self._create_key_pair_azure()
                priv_key_path = Path(priv_key_name).resolve()
                pub_key_path = Path(pub_key_name).resolve()
                self.configuration["general"]["key_name"] = priv_key_name[:-4]
                self.configuration["azure"]["private_key_path"] = str(priv_key_path)
                self.configuration["azure"]["public_key_path"] = str(pub_key_path)
                print(
                    f"> New Azure ssh pair created:\nprivate key: {priv_key_path}\npublic key: {pub_key_path}"
                )

            elif provider == "gcp":
                priv_key_name, pub_key_name = (
                    self._create_key_pair_azure()
                )  # Reuse Azure method for GCP
                priv_key_path = Path(priv_key_name).resolve()
                pub_key_path = Path(pub_key_name).resolve()
                self.configuration["general"]["key_name"] = priv_key_name[:-4]
                self.configuration["gcp"]["private_key_path"] = str(priv_key_path)
                self.configuration["gcp"]["public_key_path"] = str(pub_key_path)
                print(
                    f"> New GCP ssh pair created:\nprivate key: {priv_key_path}\npublic key: {pub_key_path}"
                )

    def _configure_network_settings(self) -> None:
        """Configure network-related settings."""
        provider = self.configuration["general"]["cloud_provider"]

        questions = [
            {
                "type": "text",
                "message": "Enter ssh key name",
                "name": "key_name",
                "default": "attack-range-key-pair",
                "when": lambda answers: "key_name" not in self.configuration["general"],
            },
            {
                "type": "text",
                "message": "Enter private key path for machine access",
                "name": "private_key_path",
                "default": "~/.ssh/id_rsa",
                "when": lambda answers: "key_name" not in self.configuration["general"],
            },
            {
                "type": "text",
                "message": "Enter public key path for machine access",
                "name": "public_key_path",
                "default": "~/.ssh/id_rsa.pub",
                "when": lambda answers: (
                    provider in ["azure", "gcp"]
                    and "key_name" not in self.configuration["general"]
                ),
            },
            {
                "type": "input",
                "message": "Enter region to build in",
                "name": "region",
                "default": self.configuration.get(provider, {}).get("region", ""),
            },
            {
                "type": "text",
                "message": (
                    "Enter public ips that are allowed to reach the attack_range"
                ),
                "name": "ip_whitelist",
                "default": f"{self.external_ip}/32",
            },
            {
                "type": "text",
                "message": "Enter attack_range name",
                "name": "attack_range_name",
                "default": "ar",
            },
        ]

        if provider == "gcp":
            questions.append(
                {
                    "type": "input",
                    "message": "Enter GCP zone",
                    "name": "zone",
                    "default": self.configuration["gcp"].get("zone", "europe-west3-a"),
                }
            )

        answers = questionary.prompt(questions)

        if "key_name" in answers:
            self.configuration["general"]["key_name"] = answers["key_name"]

        if "private_key_path" in answers:
            key_path = answers["private_key_path"]
            self.configuration[provider]["private_key_path"] = key_path

        if "public_key_path" in answers:
            self.configuration[provider]["public_key_path"] = answers["public_key_path"]

        if "region" in answers:
            if provider == "aws":
                self.configuration["aws"]["region"] = answers["region"]
            elif provider == "azure":
                self.configuration["azure"]["location"] = answers["region"]
            elif provider == "gcp":
                self.configuration["gcp"]["region"] = answers["region"]

        if provider == "gcp" and "zone" in answers:
            self.configuration["gcp"]["zone"] = answers["zone"]

        self.configuration["general"]["ip_whitelist"] = answers["ip_whitelist"]
        self.configuration["general"]["attack_range_name"] = answers[
            "attack_range_name"
        ]

    def _configure_windows_servers(self) -> None:
        """Configure Windows server settings."""
        questions = [
            {
                "type": "confirm",
                "message": "Shall we build a windows server",
                "name": "windows_server_one",
                "default": True,
            },
            {
                "type": "select",
                "message": "Which version should it be",
                "name": "windows_server_one_version",
                "choices": ["2016", "2019", "2022"],
                "when": lambda answers: answers["windows_server_one"],
            },
            {
                "type": "confirm",
                "message": "Should the windows server be a domain controller",
                "name": "windows_server_one_dc",
                "default": False,
                "when": lambda answers: answers["windows_server_one"],
            },
            {
                "type": "confirm",
                "message": "Should we install red team tools on the windows server",
                "name": "windows_server_one_red_team_tools",
                "default": False,
                "when": lambda answers: answers["windows_server_one"],
            },
            {
                "type": "confirm",
                "message": "Should we install badblood on the windows server, which will populate the domain with objects",
                "name": "windows_server_one_bad_blood",
                "default": False,
                "when": lambda answers: answers["windows_server_one"]
                and answers["windows_server_one_dc"],
            },
        ]

        answers = questionary.prompt(questions)

        if answers["windows_server_one"]:
            self.configuration["windows_servers"] = [
                {
                    "hostname": "ar-win-1",
                    "windows_image": f"windows-server-{answers['windows_server_one_version']}",
                }
            ]

            if answers["windows_server_one_dc"]:
                self.configuration["windows_servers"][0]["create_domain"] = "1"
                self.configuration["windows_servers"][0]["hostname"] = "ar-win-dc"

            if answers["windows_server_one_red_team_tools"]:
                self.configuration["windows_servers"][0]["install_red_team_tools"] = "1"

            if answers.get("windows_server_one_bad_blood"):
                self.configuration["windows_servers"][0]["bad_blood"] = "1"

    def _configure_linux_servers(self) -> None:
        """Configure Linux server settings."""
        questions = [
            {
                "type": "confirm",
                "message": "Shall we build a linux server",
                "name": "linux_server",
                "default": False,
            },
            {
                "type": "confirm",
                "message": "Shall we build a kali linux machine",
                "name": "kali_machine",
                "default": False,
                "when": lambda answers: self.configuration["general"]["cloud_provider"]
                == "aws",
            },
            {
                "type": "confirm",
                "message": "Shall we build nginx plus web proxy",
                "name": "nginx_web_proxy",
                "default": False,
                "when": lambda answers: self.configuration["general"]["cloud_provider"]
                == "aws",
            },
            {
                "type": "confirm",
                "message": "Shall we build zeek server",
                "name": "zeek_server",
                "default": False,
                "when": lambda answers: self.configuration["general"]["cloud_provider"]
                == "aws",
            },
            {
                "type": "confirm",
                "message": "Shall we build snort server",
                "name": "snort_server",
                "default": False,
                "when": lambda answers: self.configuration["general"]["cloud_provider"]
                == "aws",
            },
            {
                "type": "confirm",
                "message": "Shall we include Splunk SOAR",
                "name": "phantom",
                "default": False,
                "when": lambda answers: self.configuration["general"]["cloud_provider"]
                != "gcp",
            },
            {
                "type": "text",
                "message": "Download the Splunk SOAR unpriv installer and save it in the apps folder. What is the name of the file?",
                "name": "phantom_installer",
                "when": lambda answers: answers.get("phantom", False),
            },
        ]

        answers = questionary.prompt(questions)

        if answers["linux_server"]:
            self.configuration["linux_servers"] = [{"hostname": "ar-linux"}]

        if self.configuration["general"]["cloud_provider"] == "aws":
            if answers["kali_machine"]:
                self.configuration["kali_server"] = {"kali_server": "1"}

            if answers["nginx_web_proxy"]:
                self.configuration["nginx_server"] = {"nginx_server": "1"}

            if answers["zeek_server"]:
                self.configuration["zeek_server"] = {"zeek_server": "1"}

            if answers["snort_server"]:
                self.configuration["snort_server"] = {"snort_server": "1"}

        if answers.get("phantom", False):
            self.configuration["phantom_server"] = {"phantom_server": "1"}

        if "phantom_installer" in answers:
            self.configuration["phantom_server"]["phantom_app"] = answers[
                "phantom_installer"
            ]

    def _save_configuration(self) -> None:
        """Save the configuration to a file."""
        with open(self.config_path, "w") as outfile:
            yaml.dump(
                self.configuration, outfile, default_flow_style=False, sort_keys=False
            )

        print(f"> Configuration file was written to: {self.config_path.resolve()}")
        print("> Run `python attack_range.py build` to create a new attack_range")
        print("> You can also edit this file to configure advance parameters")

    def create_new_configuration(self) -> None:
        """Create a new configuration file with user input."""
        if self.config_path.is_file():
            questions = [
                {
                    "type": "confirm",
                    "message": f"File {self.config_path} already exists, are you sure you want to continue?\nTHIS WILL OVERWRITE YOUR CURRENT CONFIG!",
                    "name": "continue",
                    "default": True,
                },
            ]

            answers = questionary.prompt(questions)
            if not answers["continue"]:
                print(
                    "> Exiting, to create a unique configuration file in another location use the --config flag"
                )
                sys.exit(0)

        print(
            """
           ________________
         |'-.--._ _________:
         |  /    |  __    __\\\\
         | |  _  | [\\_\\= [\\_\\
         | |.' '. \\.........|
         | ( <)  ||:       :|_
          \\ '._.' | :.....: |_(o
           '-\\_   \\ .------./
           _   \\   ||.---.||  _
          / \\  '-._|/\\n~~\\n' | \\\\
         (| []=.--[===[()]===[) |
         <\\_/  \\_______/ _.' /_/
         ///            (_/_/
         |\\\\            [\\\\
         ||:|           | I|
         |::|           | I|
         ||:|           | I|
         ||:|           : \\:
         |\\:|            \\I|
         :/\\:            ([])
         ([])             [|
          ||              |\\_
         _/_\\_            [ -'-.__
    snd <]   \\>            \\_____.>
          \\__/
starting configuration for AT-ST mech walker
        """
        )

        self.external_ip = self._get_external_ip()

        self._configure_cloud_provider()
        self._configure_ssh_keys()
        self._configure_network_settings()
        self._configure_windows_servers()
        self._configure_linux_servers()
        self._save_configuration()

        print("> Setup has finished successfully ... exiting")
        sys.exit(0)


def new(config: str) -> None:
    """Create a new configuration file.

    Args:
        config: Path to the configuration file
    """
    manager = ConfigurationManager(config)
    manager.create_new_configuration()

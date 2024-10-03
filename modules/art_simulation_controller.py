
import ansible_runner
import os
import shutil

from modules.simulation_controller import SimulationController
from modules import aws_service, azure_service


class ArtSimulationController(SimulationController):

    def simulate(self, target, technique) -> None:
        if self.config['general']['cloud_provider'] == 'aws':
            try:
                public_ip = aws_service.get_single_instance_public_ip(target, self.config['general']['key_name'], self.config['general']['attack_range_name'], self.config['aws']['region'])
            except Exception as e:
                public_ip = None
            private_ip = aws_service.get_single_instance_private_ip(target, self.config['general']['key_name'], self.config['general']['attack_range_name'], self.config['aws']['region'])
            target_ip = public_ip if public_ip else private_ip
            private_key_path = self.config['aws']['private_key_path']
            if "win" in target:
                ansible_user = 'Administrator'
                ansible_port = 5985
                cmd_line=str('-i ' + target_ip + ', ')
            else:
                ansible_user = 'ubuntu'
                ansible_port = 22
                cmd_line = '-u ' + ansible_user + ' --private-key ' + private_key_path + ' -i ' + target_ip + ', '

        elif self.config['general']['cloud_provider'] == 'azure':
            target_ip = azure_service.get_instance(target, self.config['general']['key_name'], self.config['general']['attack_range_name'])['public_ip']
            if "win" in target:
                ansible_user = 'AzureAdmin'
                ansible_port = 5985
                cmd_line=str('-i ' + target_ip + ', ')
            else:
                ansible_user = 'ubuntu'
                ansible_port = 22
                cmd_line = '-u ' + ansible_user + ' --private-key ' + private_key_path + ' -i ' + target_ip + ', '
            private_key_path = self.config['azure']['private_key_path']

        elif self.config['general']['cloud_provider'] == 'local':
            ansible_user = 'Administrator'
            target_ip = '192.168.56.' + str(14 + int(target[-1]))
            if "win" in target:
                ansible_port = 5985 + int(target[-1])
                cmd_line=str('-i ' + target_ip + ', ')
            else:
                ansible_port = 2022 + int(target[-1])
                cmd_line = '-u vagrant --private-key vagrant/.vagrant/machines/' + target + '/virtualbox/private_key -i ' + target_ip + ', '

        techniques = technique.split(',')

        if "win" in target:
            runner = ansible_runner.run(
                private_data_dir=os.path.join(os.path.dirname(__file__), '../'),
                cmdline=cmd_line,
                roles_path=os.path.join(os.path.dirname(__file__), 'ansible/roles'),
                playbook=os.path.join(os.path.dirname(__file__), 'ansible/atomic_red_team.yml'),
                extravars= {
                    'ansible_port': ansible_port,
                    'ansible_connection': 'winrm',
                    'ansible_winrm_server_cert_validation': 'ignore',
                    'techniques': techniques,
                    'ansible_user': ansible_user,
                    'ansible_password': self.config['general']['attack_range_password'],
                    'art_repository': self.config['simulation']['atomic_red_team_repo'],
                    'art_branch': self.config['simulation']['atomic_red_team_branch']
                },
                verbosity=0
            )

        elif "linux" in target:
            runner = ansible_runner.run(
                private_data_dir=os.path.join(os.path.dirname(__file__), '../'),
                cmdline=cmd_line,
                roles_path=os.path.join(os.path.dirname(__file__), 'ansible/roles'),
                playbook=os.path.join(os.path.dirname(__file__), 'ansible/atomic_red_team.yml'),
                extravars= {
                    'ansible_port': ansible_port,
                    'ansible_python_interpreter': '/usr/bin/python3',
                    'techniques': techniques,
                    'art_repository': self.config['simulation']['atomic_red_team_repo'],
                    'art_branch': self.config['simulation']['atomic_red_team_branch']
                },
                verbosity=0
            )

        shutil.rmtree(os.path.join(os.path.dirname(__file__), '../artifacts'))
        shutil.rmtree(os.path.join(os.path.dirname(__file__), '../env'))
# CapAttack
CapAttack is a client capture agent for Windows, Mac and Linux developed by SnapAttack. It captures logs, network traffic and other information from the machine. Additionally, it can record the screen of the machine.

## CapAttack during attack simulation
CapAttack can be enabled by setting the parameter `cap_attack` to 1 in the `attack_range.yml` file.
```yml
simulation:
  cap_attack: "1"
```
This will start the CapAttack agent before the attack simulation is started and capture the logs, network traffic and screen. At the end of the attack simulation, the CapAttack agent will be stopped.

When you want to upload the CapAttack capture to SnapAttack, you need to set the parameters `cap_attack_upload_threat_capture` and `snapattack_api_key` in the `attack_range.yml` file.
```yml
simulation:
  cap_attack: "1"
  cap_attack_upload_threat_capture: "1"
  snapattack_api_key: "your_snapattack_api_key"
```

## Manually start and stop CapAttack
You can manually start and stop CapAttack by using the following commands:
```bash
python attack_range.py cap_attack start --target <target>
python attack_range.py cap_attack stop --target <target>
```

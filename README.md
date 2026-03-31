## IDLE-CPU-SAVE SYSTEMD SERVICE
Systemd service/timer workflow that switches CPU governors when the user becomes idle or active.

## Installation

1. Copy the provided `.config` and `.local` folders into your home directory:

	```shell
	cp -rv .config ~/
	cp -rv .local ~/
	chmod +x ~/.local/bin/idle-cpu-save.sh
	```

2. Confirm `cpupower` binary location:

	```shell
	which cpupower || command -v cpupower
	```

3. Add a sudoers rule (requires root) allowing execution of cpupower:
	```shell
	echo "$(whoami) ALL=(root) NOPASSWD: $(which cpupower)" | sudo tee /etc/sudoers.d/50-idle-cpu-save
	```

	Verify produced file syntax with:

	```shell
	sudo visudo -c -f /etc/sudoers.d/50-idle-cpu-save
	```

4. Reload and enable the timer/service (user-level):

	```shell
	systemctl --user daemon-reload
	systemctl --user enable --now idle-cpu-save.timer
	```


## Configuration
*After changing any configuration be sure to reload with* `systemctl --user daemon-reload`
- Configure desired active and idle governors

	Use the `GOV_IDLE` and `GOV_ACTIVE` environment variables in `idle-cpu-save.service`.  
	Set to correct values like `powersave`, `performance`, `schedutil`, `ondemand` depending on your kernel and cpupower support.  
	Run `cpupower frequency-info` to check.  

- Configure idle and active thresholds
	Use the `IDLE_THRESHOLD_MS` environment variable in `idle-cpu-save.service` to set the idle detection threshold (default: 120000ms = 2 minutes).  
	Use the `ACTIVE_THRESHOLD_MS` environment variable to set the active detection threshold after coming from idle (default: 20000ms = 20 seconds). This allows faster switch to active state.  


## Troubleshooting

- Test the `cpupower` command directly:
	```shell
	sudo /usr/bin/cpupower frequency-set -g schedutil
	```

- Check current governor from sysfs (no root usually required for read):
	```shell
	cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
	```

- Inspect logs:
	```shell
	journalctl --user -u idle-cpu-save.service -u idle-cpu-save.timer --since "5 minutes ago" --follow
	```

- Start the service manually for testing:
	```shell
	systemctl --user start idle-cpu-save.service
	journalctl --user -u idle-cpu-save.service --since "5 minutes ago"
	```

- Desperate Mode (enabled extra logging):
	```shell
	DEBUG=1 systemctl --user set-environment DEBUG=1
	systemctl --user daemon-reload
	journalctl --user -u idle-cpu-save.service --follow
	```
	Cleanup when done:
	```shell
	systemctl --user unset-environment DEBUG
	```


## Uninstall

1. Stop and disable the timer (user-level):

	```shell
	systemctl --user disable --now idle-cpu-save.timer
	```

2. Remove the service and timer files:

	```shell
	rm ~/.config/systemd/user/idle-cpu-save.service
	rm ~/.config/systemd/user/idle-cpu-save.timer
	systemctl --user daemon-reload
	```

3. Remove the script:

	```shell
	rm ~/.local/bin/idle-cpu-save.sh
	```

4. Remove the sudoers rule:

	```shell
	sudo rm /etc/sudoers.d/50-idle-cpu-save
	```

5. (optional) Restore a default CPU governor:

	```shell
	sudo /usr/bin/cpupower frequency-set -g powersave
	```

	check available governors with: `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors`

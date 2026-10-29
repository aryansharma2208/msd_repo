# Operations note: what to check during an outage

Work from the outside in. Each step either finds the fault or rules out a layer.

## 1. Confirm the symptom from outside

```bash
bash scripts/verify.sh http://<public-ip>
curl -v --max-time 5 http://<public-ip>/health
```

- **Connection timed out** → network path (steps 2–3).
- **Connection refused** → instance reachable but nothing on port 80 (step 4).
- **HTTP 5xx / wrong body** → application problem (step 5).

## 2. Is the instance running and is the IP the same?

```bash
aws ec2 describe-instances --filters "Name=tag:Name,Values=hello-service" \
  --query "Reservations[].Instances[].{state:State.Name,ip:PublicIpAddress,id:InstanceId}" --output table
aws ec2 describe-instance-status --instance-ids <id>   # system/instance status checks
```

The public IP changes if the instance is stopped and started (no Elastic IP is
used, to stay free). If it changed, use `terraform -chdir=terraform output`.

## 3. Is the network path open?

```bash
aws ec2 describe-security-groups --filters Name=group-name,Values=hello-service-sg
```

- Port 80 must allow `0.0.0.0/0`.
- If **SSH** fails but HTTP works, your home IP probably changed. Update
  `terraform/terraform.tfvars` and run `terraform apply`.

## 4. Is the service running? (SSH in)

```bash
ssh ec2-user@<public-ip>
systemctl status hello.service
sudo ss -ltnp | grep ':80'                 # is something listening on 80?
curl -s http://127.0.0.1/health             # works locally but not remotely → network/SG
```

## 5. What do the logs say?

```bash
journalctl -u hello.service -n 100 --no-pager           # app output + crashes
journalctl -t hello-healthcheck --since "1 hour ago"    # FAIL / RECOVERED / STILL DOWN
systemctl list-timers hello-healthcheck.timer           # is the checker running?
sudo cat /var/log/cloud-init-output.log                 # only for first-boot problems
```

A crash loop shows repeated `Started` / `Main process exited` lines. If systemd
gave up (`start-limit-hit`), run `sudo systemctl reset-failed hello.service`.

## 6. Is the host healthy?

```bash
df -h /          # full disk stops logging and writes
free -m          # memory pressure / OOM kills
uptime           # load
journalctl -k | grep -i -E "oom|killed process"
```

## 7. Recover

| Situation | Action |
|---|---|
| Process hung | `sudo systemctl restart hello.service` (the timer will also do this) |
| Bad host state | `sudo reboot` — service starts on boot |
| Instance broken / config drift | `terraform -chdir=terraform apply -replace=aws_instance.web` rebuilds it from code |

After recovery, run `bash scripts/verify.sh` again and note the cause.

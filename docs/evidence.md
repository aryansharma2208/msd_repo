# Evidence

Proof that the deployed instance (`t3.micro`, Amazon Linux 2023, ap-south-1)
behaves as the README claims. Captured on 2026-10-29 against
`http://3.110.27.143` (the IP changes on every new deploy).

## 1. Service is running under systemd

![systemctl status showing hello.service active and enabled](images/ssh-service-status.png)

## 2. Endpoints answer from the internet

```text
$ bash scripts/verify.sh http://3.110.27.143
Checking http://3.110.27.143/health ...
  OK  {"status": "ok", "uptime_seconds": 3097}
Checking http://3.110.27.143/ ...
  OK  Hello from hello-service!
Checking unknown path returns 404 ...
  OK  404
All checks passed.
```

## 3. Crash: systemd restarts the process

`SIGKILL` the service; 5 seconds later it is active again (`Restart=always`).

![hello.service killed with SIGKILL and active again after 5 seconds](images/crash-restart.png)

## 4. Hang: the health check detects it and restarts the service

The process is frozen with `SIGSTOP`, so it is still "running" but answers
nothing. The 1-minute timer probes `/health`, restarts the service and logs the
result. Recovery took about 78 s.

```text
[ec2-user@ip-172-31-9-186 ~]$ systemctl show -p MainPID hello.service
MainPID=2583
[ec2-user@ip-172-31-9-186 ~]$ sudo systemctl kill -s SIGSTOP hello.service    # 21:06:55 UTC
[ec2-user@ip-172-31-9-186 ~]$ curl -sS --max-time 3 http://127.0.0.1/health
curl: (28) Operation timed out after 3002 milliseconds with 0 bytes received
[ec2-user@ip-172-31-9-186 ~]$ journalctl -t hello-healthcheck --since -3min --no-pager
Oct 29 21:08:08 ip-172-31-9-186 hello-healthcheck[5771]: FAIL: http://127.0.0.1/health not healthy, restarting hello.service
Oct 29 21:08:13 ip-172-31-9-186 hello-healthcheck[5782]: RECOVERED: hello.service healthy after restart
[ec2-user@ip-172-31-9-186 ~]$ systemctl show -p MainPID hello.service
MainPID=5775
[ec2-user@ip-172-31-9-186 ~]$ curl -sS --max-time 3 http://127.0.0.1/health
{"status": "ok", "uptime_seconds": 9}
```

## 5. Reboot: the service starts on boot

```text
[ec2-user@ip-172-31-9-186 ~]$ uptime -s
2026-10-29 20:05:17
[ec2-user@ip-172-31-9-186 ~]$ sudo systemctl reboot              # 21:08:49 UTC

# from the laptop, polling /health every 5 s:
healthy again after ~10s at Thu Oct 29 21:09:05 UTC 2026

$ bash scripts/verify.sh http://3.110.27.143
Checking http://3.110.27.143/health ...
  OK  {"status": "ok", "uptime_seconds": 0}
Checking http://3.110.27.143/ ...
  OK  Hello from hello-service!
Checking unknown path returns 404 ...
  OK  404
All checks passed.

[ec2-user@ip-172-31-9-186 ~]$ uptime -s
2026-10-29 21:08:58
[ec2-user@ip-172-31-9-186 ~]$ systemctl is-enabled hello.service hello-healthcheck.timer
enabled
enabled
[ec2-user@ip-172-31-9-186 ~]$ systemctl is-active hello.service hello-healthcheck.timer
active
active
```

## 6. Network restrictions

Probed from the admin laptop (public IP `49.43.133.168`, the `admin_cidr`):

```text
$ curl --max-time 5 http://3.110.27.143:8080/
curl: (28) Connection timed out after 5007 milliseconds

port 22:   open              (allowed only from 49.43.133.168/32)
port 80:   open              (public)
port 8080: closed/filtered   (app's dev port, not exposed)
port 3306: closed/filtered
```

## 7. CI

See [ci-output.md](ci-output.md) for the green GitHub Actions run.

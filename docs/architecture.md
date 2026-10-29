# Architecture and request path

```mermaid
flowchart LR
    user([Internet user]) -->|HTTP :80| sg
    admin([Admin laptop<br/>your IP /32]) -->|SSH :22| sg
    subgraph AWS["AWS ap-south-1 · default VPC · public subnet"]
        sg{{Security group<br/>80 from 0.0.0.0/0<br/>22 from admin IP only}}
        subgraph ec2["EC2 t3.micro · Amazon Linux 2023"]
            svc["hello.service (systemd)<br/>python3 /opt/hello/app.py<br/>user: hello · port 80"]
            timer["hello-healthcheck.timer<br/>every 1 min"] --> hc["healthcheck.sh<br/>curl 127.0.0.1/health"]
            hc -->|restart on failure| svc
            svc --> journal[(journald logs)]
            hc --> journal
        end
        sg --> svc
    end
```

## Request path (in words)

1. A client sends `GET http://<public-ip>/` (or `/health`).
2. The request reaches the instance's public IPv4 address in the default VPC.
3. The **security group** allows it because TCP 80 is open to `0.0.0.0/0`.
   Every other port is dropped. SSH (TCP 22) is accepted only from the
   admin's own IP (`admin_cidr`, a single `/32`).
4. On the instance, **`hello.service`** (a systemd unit) runs
   `python3 /opt/hello/app.py` as the unprivileged `hello` user. It may bind
   port 80 because systemd grants only `CAP_NET_BIND_SERVICE`.
5. The app answers `/` with a text message and `/health` with
   `{"status": "ok", "uptime_seconds": N}`. Each request is logged to stdout,
   which systemd stores in journald.

## How the service stays up

| Failure | What handles it |
|---|---|
| Process crashes or is killed | `Restart=always` in `hello.service` restarts it after 3 s |
| Process alive but not answering (hung) | `hello-healthcheck.timer` runs `healthcheck.sh` every minute; two failed probes → `systemctl restart hello.service`, result logged |
| Instance reboots | Both units are `enabled`, so systemd starts them on boot |
| Still down after restart | Health check logs `STILL DOWN` at error priority and exits 1 (visible in `systemctl status hello-healthcheck`) |

## How it is deployed

`scripts/deploy.sh` → `terraform apply` creates a key pair, a security group
and one EC2 instance. Terraform renders `terraform/user_data.sh.tftpl` with
the app and unit files embedded; cloud-init runs it once at first boot. A
change to any of those files makes Terraform replace the instance.

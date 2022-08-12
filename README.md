# shield

This container makes the underlying host "magically" disappear during network attacks.

## Installation

### Docker

```bash
docker run -d --rm --network="host" --privileged --name shield [ -e "SSH_PORT=65000" -e "PORTSCAN=21,22,23,135,389,636,1433,3306,5432,8086,10000,25565" -e "INTERFACE=eth0" ] 300481/shield:0.3.0
```

### Kubernetes Helm Chart

Find more info on [Artifact HUB](https://artifacthub.io/packages/helm/dr300481/shield)

[Helm Chart Source](./charts/shield/README.md)

### RacherOS service

Code snippet for cloud-config.yml

```yaml
rancher:
  environment:
    SSH_PORT: 65000
    INTERFACE: eth0
  repositories:
    shield:
      url: https://raw.githubusercontent.com/300481/shield/master
  services_include:
    shield: true
```

## Configuration

### By Environment

|Variable|Description|Default Value|
|--------|-----------|-------------|
|`PORTSCAN`|The comma separated list of ports, which will be trapped, when scanned. Then the source IP will be blocked.|`21,22,23,135,389,636,1433,3306,5432,8086,10000,25565`|
|`SSH_PORT`|The SSH port.|`65000`|
|`INTERFACE`|The Network Interface to protect.|`eth0`|

## Contribution

Everyone who likes, is welcomed to contribute to this project.

Just fork and make a pull request or open an issue.

I'll respond as soon as I can.

## Related Article

Find additional information on [Medium](https://dennis-riemenschneider.medium.com/make-your-server-invisible-on-attacks-by-just-using-a-simple-docker-container-80d19f13c8f7).

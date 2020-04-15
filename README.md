# shield

This Docker Container configures the iptables of the underlying host

to protect it with best effort from network attacks.

## configuration by environment

|Variable|Description|Default Value|
|--------|-----------|-------------|
|`PORTSCAN`|The comma separated list of ports, which will be trapped, when scanned. Then the source IP will be blocked.|`21,22,23,135,389,636,1433,3306,5432,8086,10000,25565`|
|`SSH_PORT`|The SSH port.|`65000`|

## contribution

Everyone who likes, is welcomed to contribute to this project.

Find additional information on [Medium](https://medium.com/@dennis.riemenschneider/configure-the-firewall-of-a-docker-server-d048b7e02871).

## start container

### with docker

```bash
docker run -d --rm --network="host" --privileged --name shield [ -e "SSH_PORT=65000" -e "PORTSCAN=21,22,23,135,389,636,1433,3306,5432,8086,10000,25565" ] 300481/shield:0.1.4
```

### cloud-config snippet for RacherOS

```yaml
rancher:
  environment:
    SSH_PORT: 65000
  repositories:
    shield:
      url: https://raw.githubusercontent.com/300481/shield/master
  services_include:
    shield: true
```

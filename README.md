# rancheros-firewall

## purpose

If you install a blank RancherOS VM facing directly the internet, it has doors wide opened.

The purpose of this service is to have an as good as possible

network protection with iptables-rules for the RancherOS server.

## environment

|Variable|Description|Default Value|
|--------|-----------|-------------|
|`PORTSCAN`|The comma separated list of ports, which will be trapped, when scanned. Then the source IP will be blocked.|`21,22,23,135,389,636,1433,3306,5432,8086,10000,25565`|
|`SSH_PORT`|The SSH port.|`65000`|

## contribution

Everyone who likes, is welcomed to contribute to this project.

## cloud-config snippet

```yaml
rancher:
  environment:
    SSH_PORT: 65000
  repositories:
    rancheros-firewall:
      url: https://raw.githubusercontent.com/300481/rancheros-firewall/master
  services_include:
    rancheros-firewall: true
```

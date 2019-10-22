# rancheros-firewall

## purpose

If you install a blank RancherOS VM facing directly the internet, it has doors wide opened.

The purpose of this service is to have an as good as possible

network protection with iptables-rules for the RancherOS server.


## contribution

Everyone who likes, is welcomed to contribute to this project.


## cloud-config snippet

```yaml
rancher:
  repositories:
    rancheros-firewall:
      url: https://raw.githubusercontent.com/300481/rancheros-firewall/master
  services_include:
    rancheros-firewall: true
```

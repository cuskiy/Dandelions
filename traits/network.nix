{ ... }:
{
  schema.network = {
    hostname = "NixOS";
    machineId = "00000000";
    useWireless = true;
    useNetworkManager = true;
  };

  traits.network =
    { config, lib, schema, ... }:
    let
      cfg = schema.network // config.networking.firewall;
      ifaceSet = lib.concatStringsSep ", " (map (x: ''"${x}"'') cfg.trustedInterfaces);
    in
    {
      networking = {
        hostName = lib.mkDefault cfg.hostname;
        hostId = cfg.machineId;
        dhcpcd.enable = false;
        networkmanager.enable = cfg.useNetworkManager;
        networkmanager.wifi.backend = lib.mkIf cfg.useWireless "iwd";
        wireless.iwd.enable = cfg.useWireless;
        useNetworkd = !cfg.useNetworkManager;
        useDHCP = !cfg.useNetworkManager;
      };
      systemd.network.enable = !cfg.useNetworkManager;

      networking.resolvconf.enable = false;
      services.resolved.enable = false;
      environment.etc."resolv.conf".text = ''
        nameserver 1.1.1.1
        nameserver 2606:4700:4700::1111
        nameserver 8.8.8.8
        nameserver 2001:4860:4860::8888
      '';

      networking.firewall.enable = false;
      networking.nftables.enable = true;
      networking.nftables.ruleset = ''
        table inet filter {
          chain input {
            type filter hook input priority filter; policy drop;
            iifname "lo" accept
            ${lib.optionalString (ifaceSet != "") "iifname { ${ifaceSet} } accept"}

            icmp type echo-request accept
            icmpv6 type != { nd-redirect, 139 } accept

            ip6 daddr fe80::/64 udp dport 546 accept

            meta nfproto ipv4 udp sport . udp dport { 68 . 67, 67 . 68 } accept
            meta nfproto ipv4 fib saddr . mark . iif oif exists accept

            ct state invalid drop
            ct state { established, related } accept
            ct state { new, untracked } jump input-allow
          }
          chain input-allow {
            ${lib.concatStrings (
              lib.mapAttrsToList (
                iface: cfg:
                let
                  ifaceMatch = if iface == "default" then "" else "iifname \"${iface}\" ";
                  portsToNftSet =
                    ports: portRanges:
                    lib.concatStringsSep ", " (
                      map (x: toString x) ports ++ map (x: "${toString x.from}-${toString x.to}") portRanges
                    );
                  tcpSet = portsToNftSet cfg.allowedTCPPorts cfg.allowedTCPPortRanges;
                  udpSet = portsToNftSet cfg.allowedUDPPorts cfg.allowedUDPPortRanges;
                in
                ''
                  ${lib.optionalString (tcpSet != "") "${ifaceMatch}tcp dport { ${tcpSet} } accept"}
                  ${lib.optionalString (udpSet != "") "${ifaceMatch}udp dport { ${udpSet} } accept"}
                ''
              ) cfg.allInterfaces
            )}
            ${cfg.extraInputRules}
          }

          chain forward {
            type filter hook forward priority filter; policy drop;
            ct state invalid drop
            ct state { established, related } accept
            ct state { new, untracked } jump forward-allow
          }
          chain forward-allow {
            icmpv6 type != { router-renumbering, 139 } accept
            ct status dnat accept
            ${cfg.extraForwardRules}
          }

          chain output {
            type filter hook output priority filter; policy accept;
            ct state invalid drop
          }
        }
      '';
    };
}

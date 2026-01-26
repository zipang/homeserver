{ config, pkgs, ... }:

{
  # --- 1. Samba Server Configuration ---
  services.samba = {
    enable = true;
    openFirewall = true;
    
    # Modern NixOS (25.11+) uses settings instead of extraConfig/shares
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "SKYLAB";
        "netbios name" = "SKYLAB";
        security = "user";
        # use guest account if user authentication fails
        "map to guest" = "bad user";
        "guest account" = "nobody";
      };

      Skylab = {
        path = "/share/Skylab";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "force user" = "zipang";
        "create mask" = "0644";
        "directory mask" = "0755";
      };

      Storage = {
        path = "/share/Storage";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "force user" = "zipang";
        "create mask" = "0644";
        "directory mask" = "0755";
      };
    };
  };

  # --- 2. Discovery Services (mDNS / WSDD) ---
  # Avahi for discovery on MacOS/Linux
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      hinfo = true;
      userServices = true;
      workstation = true;
    };
    extraServiceFiles = {
      smb = ''
        <?xml version="1.0" standalone='no'?>
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">%h</name>
          <service>
            <type>_smb._tcp</type>
            <port>445</port>
          </service>
          <service>
            <type>_device-info._tcp</type>
            <port>0</port>
            <txt-record>model=RackMac</txt-record>
          </service>
        </service-group>
      '';
    };
  };

  # WSDD for discovery on modern Windows and Linux clients
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };
}

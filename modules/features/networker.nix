# Live connection map behind the network panel. Builds networker's collector
# with our own live-only entrypoint (patches/networker-live), so its eBPF
# capture and GeoIP lookup are reused while no history is ever stored.
{ ... }:
{
  flake.nixosModules.networker =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.services.networker;
      src = pkgs.fetchFromGitHub {
        owner = "tagptroll1";
        repo = "networker";
        rev = "64769351fd533e9598c9f9e28b35b972a1ea2d52";
        hash = "sha256-q2a4FzLL6Vao7sqmxpKXDFX9bixam+vxG7JZiEz+jPQ=";
      };
      package = (pkgs.buildGoModule.override { go = pkgs.go_1_27; }) {
        pname = "networker-live";
        version = "0-unstable-2026-09-26";
        inherit src;
        # Inside the module tree so it can import networker's internal packages.
        postPatch = ''
          cp -r ${../../patches/networker-live}/. .
        '';
        vendorHash = "sha256-6mJ584sc1AgFUVJTnLEYw6ccSnqW1wkumW/XryUUfPU=";
        subPackages = [ "cmd/networker-live" ];
        env.CGO_ENABLED = 0;
      };
      # eBPF load and cgroup attach, plus reading every user's /proc/*/fd to
      # attribute sockets to processes. ProtectProc stays default for the same reason.
      capabilities = [
        "CAP_BPF"
        "CAP_PERFMON"
        "CAP_NET_ADMIN"
        "CAP_SYS_PTRACE"
        "CAP_DAC_READ_SEARCH"
      ];
    in
    {
      options.services.networker = {
        enable = lib.mkEnableOption "the live-only networker collector" // {
          default = true;
        };
        origin = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.submodule {
              options.latitude = lib.mkOption { type = lib.types.float; };
              options.longitude = lib.mkOption { type = lib.types.float; };
            }
          );
          default = null;
          description = "Approximate map origin. Without it the map shows no routes.";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.networker = {
          description = "Live network connection collector";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            ExecStart = lib.escapeShellArgs (
              [
                (lib.getExe' package "networker-live")
                # The network panel's ConnectionMap.qml queries this. Off
                # networker's own 8765, so a dev run beside it does not clash.
                "-listen"
                "127.0.0.1:8766"
                # DB-IP Lite is CC-BY and packaged, unlike GeoLite2.
                "-city-db"
                "${pkgs.dbip-city-lite}/share/dbip/dbip-city-lite.mmdb"
                "-asn-db"
                "${pkgs.dbip-asn-lite}/share/dbip/dbip-asn-lite.mmdb"
              ]
              ++ lib.optionals (cfg.origin != null) [
                "-origin-lat"
                (toString cfg.origin.latitude)
                "-origin-lon"
                (toString cfg.origin.longitude)
              ]
            );
            Restart = "on-failure";
            DynamicUser = true;
            AmbientCapabilities = capabilities;
            CapabilityBoundingSet = capabilities;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            # Read-only cgroupfs is enough: attach only needs an fd to the root.
            ProtectControlGroups = true;
            RestrictNamespaces = true;
            LockPersonality = true;
            SystemCallArchitectures = "native";
            MemoryDenyWriteExecute = true;
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_UNIX"
            ];
          };
        };
      };
    };
}

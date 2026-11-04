# Traffic collector behind the network panel. Each part is optional: this host
# runs the live feed and the snitch, with no history or web dashboard. All of
# it is passed as NETWORKER_* environment, see networker's README.
{ inputs, ... }:
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
      frontend = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
        pname = "networker-dashboard";
        version = "0-unstable";
        src = "${cfg.src}/frontend";
        pnpmDeps = pkgs.fetchPnpmDeps {
          inherit (finalAttrs) pname version src;
          pnpm = pkgs.pnpm;
          fetcherVersion = 4;
          hash = "sha256-8Z67cHRtLgkyyGtHG+ahkBS1pFuVM9cgGTERVQWzONQ=";
        };
        nativeBuildInputs = [
          pkgs.nodejs
          pkgs.pnpm
          pkgs.pnpmConfigHook
        ];
        buildPhase = ''
          runHook preBuild
          pnpm run build
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          cp -r build $out
          runHook postInstall
        '';
      });
      package = (pkgs.buildGoModule.override { go = pkgs.go_1_27; }) {
        pname = "networker";
        version = "0-unstable";
        inherit (cfg) src;
        vendorHash = "sha256-VdO51G+fzbA8JVdJfaYV03ecgWT1gnedQc+okh/pqTw=";
        subPackages = [ "cmd/networker" ];
        env.CGO_ENABLED = 0;
        # The dashboard embeds a Node build; skip that toolchain when unused.
        tags = lib.optional (!cfg.dashboard.enable) "headless";
        preBuild = lib.optionalString cfg.dashboard.enable ''
          cp -r ${frontend} frontend/build
        '';
        overrideModAttrs = _: { preBuild = ""; };
        meta.mainProgram = "networker";
      };
      rulesFile = pkgs.writeText "networker-rules.json" (
        builtins.toJSON (map (lib.filterAttrs (_: value: value != null)) cfg.snitch.rules)
      );
      # eBPF load and cgroup attach, plus reading every user's /proc/*/fd to
      # attribute sockets to processes. ProtectProc stays default for the same reason.
      capabilities = lib.optionals cfg.capture.enable [
        "CAP_BPF"
        "CAP_PERFMON"
        "CAP_NET_ADMIN"
        "CAP_SYS_PTRACE"
        "CAP_DAC_READ_SEARCH"
      ];
      stateful = cfg.history.enable || cfg.snitch.enable;
    in
    {
      options.services.networker = {
        enable = lib.mkEnableOption "the networker collector" // {
          default = true;
        };
        src = lib.mkOption {
          type = lib.types.path;
          default = inputs.networker;
          defaultText = lib.literalExpression "inputs.networker";
          description = "networker source tree.";
        };
        # The network panel's ConnectionMap.qml queries this. Off networker's
        # own 8765, so a dev run beside it does not clash.
        listen = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1:8766";
          description = "Numeric loopback address and port of the HTTP API.";
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
        # DB-IP Lite is CC-BY and packaged, unlike GeoLite2.
        cityDb = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = "${pkgs.dbip-city-lite}/share/dbip/dbip-city-lite.mmdb";
          defaultText = lib.literalExpression "DB-IP City Lite";
          description = "City MMDB for locating destinations; null disables locations.";
        };
        asnDb = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = "${pkgs.dbip-asn-lite}/share/dbip/dbip-asn-lite.mmdb";
          defaultText = lib.literalExpression "DB-IP ASN Lite";
          description = "ASN MMDB naming destination networks; needs cityDb.";
        };
        capture.enable = lib.mkEnableOption "this host's eBPF traffic capture" // {
          default = true;
        };
        history = {
          enable = lib.mkEnableOption "the connection history database";
          retention = lib.mkOption {
            type = lib.types.str;
            default = "720h";
            description = "How long to keep connection summaries.";
          };
          maxRecords = lib.mkOption {
            type = lib.types.ints.positive;
            default = 50000;
            description = "Row limit per history table.";
          };
        };
        dashboard.enable = lib.mkEnableOption "the embedded web dashboard (needs history)";
        router = {
          url = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "https://192.168.88.1";
            description = "RouterOS REST base URL, to also show other LAN devices.";
          };
          user = lib.mkOption {
            type = lib.types.str;
            default = "networker";
            description = "RouterOS REST user.";
          };
          passwordFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "File holding the REST password, kept out of the Nix store. Read by systemd as root.";
          };
          caFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "PEM CA that signed the router's HTTPS certificate.";
          };
        };
        snitch = {
          enable = lib.mkEnableOption "per-app tracking of outbound destinations";
          watch = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Apps alerting on every new destination, from the first one.";
          };
          quiet = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Apps that never alert: browsers reach new hosts by design.";
          };
          learnFor = lib.mkOption {
            type = lib.types.str;
            default = "24h";
            description = "How long after an app first appears its new destinations stay silent.";
          };
          retention = lib.mkOption {
            type = lib.types.str;
            default = "2160h";
            description = "Forget destinations unseen for this long.";
          };
          maxDestinations = lib.mkOption {
            type = lib.types.ints.positive;
            default = 20000;
            description = "Most destinations to remember.";
          };
          rules = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  app = lib.mkOption {
                    type = lib.types.str;
                    description = "App name as the snitch reports it, or \"*\" for everyone.";
                  };
                  host = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Domain to refuse, subdomains included.";
                  };
                  cidr = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Address or range to refuse.";
                  };
                };
              }
            );
            default = [ ];
            example = [
              {
                app = "freetube";
                host = "gvt1.com";
              }
            ];
            description = ''
              What to refuse. Only flagged in the snitch view until
              blocking.enable is set, so rules can be judged first. Fails open
              if the service stops, and domain rules rely on seeing DNS answers.
            '';
          };
          blocking.enable = lib.mkEnableOption "refusing connections the rules match";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = !cfg.dashboard.enable || cfg.history.enable;
            message = "services.networker.dashboard needs history.";
          }
          {
            assertion = cfg.capture.enable || cfg.router.url != null;
            message = "services.networker has nothing to collect: enable capture or set router.url.";
          }
          {
            assertion = !cfg.snitch.enable || cfg.capture.enable;
            message = "services.networker.snitch needs capture: routers report no process details.";
          }
          {
            assertion = !cfg.snitch.blocking.enable || cfg.snitch.enable;
            message = "services.networker.snitch.blocking needs snitch.";
          }
          {
            assertion = cfg.router.url == null || (cfg.router.passwordFile != null && cfg.router.caFile != null);
            message = "services.networker.router.url needs passwordFile and caFile.";
          }
          {
            assertion = builtins.all (rule: (rule.host == null) != (rule.cidr == null)) cfg.snitch.rules;
            message = "services.networker.snitch.rules: set exactly one of host and cidr per rule.";
          }
        ];

        systemd.services.networker = {
          description = "Network traffic collector";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          environment = lib.filterAttrs (_: value: value != null) (
            {
              NETWORKER_LISTEN = cfg.listen;
              NETWORKER_CITY_DB = if cfg.cityDb == null then null else toString cfg.cityDb;
              NETWORKER_ASN_DB = if cfg.asnDb == null then null else toString cfg.asnDb;
              NETWORKER_CAPTURE = lib.boolToString cfg.capture.enable;
              NETWORKER_HISTORY = lib.boolToString cfg.history.enable;
              NETWORKER_DASHBOARD = lib.boolToString cfg.dashboard.enable;
              NETWORKER_SNITCH = lib.boolToString cfg.snitch.enable;
            }
            // lib.optionalAttrs (cfg.origin != null) {
              NETWORKER_ORIGIN_LAT = toString cfg.origin.latitude;
              NETWORKER_ORIGIN_LON = toString cfg.origin.longitude;
            }
            // lib.optionalAttrs cfg.history.enable {
              NETWORKER_HISTORY_DB = "/var/lib/networker/history.db";
              NETWORKER_HISTORY_RETENTION = cfg.history.retention;
              NETWORKER_HISTORY_MAX_RECORDS = toString cfg.history.maxRecords;
            }
            // lib.optionalAttrs (cfg.router.url != null) {
              NETWORKER_ROUTER_URL = cfg.router.url;
              NETWORKER_ROUTER_USER = cfg.router.user;
              NETWORKER_ROUTER_PASSWORD_FILE = "%d/router-password";
              NETWORKER_ROUTER_CA = toString cfg.router.caFile;
            }
            // lib.optionalAttrs cfg.snitch.enable {
              NETWORKER_SNITCH_DB = "/var/lib/networker/snitch.db";
              NETWORKER_SNITCH_RULES = toString rulesFile;
              NETWORKER_SNITCH_ENFORCE = lib.boolToString cfg.snitch.blocking.enable;
              NETWORKER_SNITCH_WATCH = lib.concatStringsSep "," cfg.snitch.watch;
              NETWORKER_SNITCH_QUIET = lib.concatStringsSep "," cfg.snitch.quiet;
              NETWORKER_SNITCH_LEARN = cfg.snitch.learnFor;
              NETWORKER_SNITCH_RETENTION = cfg.snitch.retention;
              NETWORKER_SNITCH_MAX_DESTINATIONS = toString cfg.snitch.maxDestinations;
            }
          );
          serviceConfig = {
            ExecStart = lib.getExe package;
            Restart = "on-failure";
            DynamicUser = true;
            AmbientCapabilities = capabilities;
            CapabilityBoundingSet = capabilities;
            StateDirectory = lib.mkIf stateful "networker";
            LoadCredential = lib.mkIf (cfg.router.url != null) "router-password:${cfg.router.passwordFile}";
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

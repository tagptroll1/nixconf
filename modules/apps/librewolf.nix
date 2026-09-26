# librewolf - managed by the Packages menu
{
  apps.librewolf = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { ... }:
      {
        home.sessionVariables.BROWSER = "librewolf";

        # overwrite pre-existing hand-written mimeapps.list
        xdg.configFile."mimeapps.list".force = true;

        xdg.mimeApps = {
          enable = true;
          defaultApplications = {
            # carried over from old hand-written mimeapps.list
            "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
            "x-scheme-handler/discord" = "vesktop.desktop";
            "text/html" = "librewolf.desktop";
            "text/xml" = "librewolf.desktop";
            "application/xhtml+xml" = "librewolf.desktop";
            "x-scheme-handler/http" = "librewolf.desktop";
            "x-scheme-handler/https" = "librewolf.desktop";
            "x-scheme-handler/about" = "librewolf.desktop";
            "x-scheme-handler/unknown" = "librewolf.desktop";
          };
        };

        programs.librewolf = {
          enable = true;
          settings = {
            "privacy.clearOnShutdown.history" = false;
            "privacy.clearOnShutdown.cookies" = false;
            # ff128+ uses _v2 prefs; old ones ignored
            "privacy.clearOnShutdown_v2.cookiesAndStorage" = false;
            "privacy.clearOnShutdown_v2.historyFormDataAndDownloads" = false;
          };
        };
      };
  };
}

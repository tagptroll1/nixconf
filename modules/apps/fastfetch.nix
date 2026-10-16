# fastfetch - managed by the Packages menu
{
  apps.fastfetch = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module = {
      programs.fastfetch = {
        enable = true;
        settings.modules = [
          "title"
          "separator"
          "os"
          "kernel"
          "shell"
          {
            type = "display";
            format = "{width}x{height}, {refresh-rate}Hz";
          }
          "wm"
          "terminal"
          "cpu"
          {
            type = "gpu";
            # Blacklisted amdgpu leaves the iGPU with an unknown type.
            hideType = "unknown";
          }
          "memory"
          "break"
          "colors"
        ];
      };
    };
  };
}

{
  description = "My main baby";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    # only for xdg-desktop-portal-wlr 0.7.1: 0.8.x ext_image_copy_capture path breaks
    # screencast on mango+nvidia (frozen first frame); drop when fixed upstream
    nixpkgs-xdpw.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mangowm = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # 2.0 is tagged but not yet in nixpkgs or npm latest
    opencode = {
      url = "github:anomalyco/opencode/v2.0.16";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}

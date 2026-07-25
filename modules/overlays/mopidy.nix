# nixpkgs still ships mopidy 3.4.2 + the mopidy-spotify 5.0.0a3 alpha, a combo that
# breaks on every setuptools/pytest bump (pkg_resources gone in setuptools 82; pytest 9
# rejects a3's parametrize). The whole ecosystem has moved to mopidy 4 stable, so bump
# the core + extensions to their current stable releases. mopidy 4 dropped pkg_resources,
# so no setuptools_80 hack is needed. Drop this overlay once nixpkgs bumps mopidy to 4.x.
{
  flake.overlays.mopidy = final: prev: {
    mopidyPackages = prev.mopidyPackages.overrideScope (
      mfinal: mprev:
      let
        pp = mfinal.python.pkgs;
        # mopidy 4 builds with setuptools-scm; feed the version so it doesn't need a
        # .git tree (fetchPypi sdists have none).
        scm = v: {
          env.SETUPTOOLS_SCM_PRETEND_VERSION = v;
          build-system = [
            pp.setuptools
            pp.setuptools-scm
          ];
        };
      in
      {
        mopidy = mprev.mopidy.overridePythonAttrs (
          old:
          {
            version = "4.0.1";
            src = final.fetchPypi {
              pname = "mopidy";
              version = "4.0.1";
              hash = "sha256-dyyfcgJz0ImfclfY7/U4FttnHVHkzYEohf77mDYGRWw=";
            };
          }
          // scm "4.0.1"
          // {
            dependencies = [
              pp.cyclopts
              pp.httpx
              pp.platformdirs
              pp.pydantic
              pp.pygobject3
              pp.pykka
              pp.rich
              pp.tornado
            ];
          }
        );
        mopidy-spotify = mprev.mopidy-spotify.overridePythonAttrs (
          old:
          {
            version = "5.0.0";
            src = final.fetchPypi {
              pname = "mopidy_spotify";
              version = "5.0.0";
              hash = "sha256-2PJL+Jf2rDXrOKh/mIT3Sp/MpU/EjEL26kXHYjmZHMI=";
            };
          }
          // scm "5.0.0"
          // {
            dependencies = [
              mfinal.mopidy
              pp.pykka
              pp.requests
            ];
            # 5.0.0 predates the pytest-9 parametrize fix (upstream 5fbc410, post-release);
            # its test collection dies under pytest 9. Apply the upstream test-only fix.
            patches = (old.patches or [ ]) ++ [
              (final.fetchpatch {
                name = "pytest-single-arg-parametrize.patch";
                url = "https://github.com/mopidy/mopidy-spotify/commit/5fbc4104d78ef15f81ef080c427551f9d4369873.patch";
                hash = "sha256-JPy9l8uKWUggpfszpwfMiuNN8abnIlno+zOCB4r5s0s=";
              })
            ];
            # tests/import-check import mopidy.core -> audio -> Gst, so the GStreamer
            # typelib must be on GI_TYPELIB_PATH during the build.
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.gobject-introspection ];
            buildInputs = (old.buildInputs or [ ]) ++ [
              final.gst_all_1.gstreamer
              final.gst_all_1.gst-plugins-base
            ];
          }
        );
        mopidy-mpd = mprev.mopidy-mpd.overridePythonAttrs (
          old:
          {
            version = "4.0.0";
            src = final.fetchPypi {
              pname = "mopidy_mpd";
              version = "4.0.0";
              hash = "sha256-DxGLHEZmXABVddE60ykGoOR3tphHjvbpUKdyCmHhasg=";
            };
          }
          // scm "4.0.0"
          // {
            dependencies = [
              mfinal.mopidy
              pp.pygobject3
              pp.pykka
            ];
          }
        );
        mopidy-mpris = mprev.mopidy-mpris.overridePythonAttrs (
          old:
          {
            version = "4.0.0";
            src = final.fetchPypi {
              pname = "mopidy_mpris";
              version = "4.0.0";
              hash = "sha256-6cQlXxqno96SMQqlheAY3SkttVpEoVJmPjGndcJ4qQA=";
            };
          }
          // scm "4.0.0"
          // {
            dependencies = [
              mfinal.mopidy
              pp.pydbus
              pp.pygobject3
              pp.pykka
            ];
          }
        );
      }
    );
    inherit (final.mopidyPackages)
      mopidy
      mopidy-mpd
      mopidy-mpris
      mopidy-spotify
      ;
  };
}

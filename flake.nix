{
  description = "sessions — a Ruby GTK4 port";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Shared libraries every ruby-gnome extension links against.
        gtkStack = with pkgs; [
          glib
          gobject-introspection
          cairo
          pango
          gdk-pixbuf
          graphene
          atk
          gtk4
          libadwaita
          harfbuzz
          librsvg
        ]
        # The Ruby `pkg-config` gem resolves `Requires.private` transitively and
        # hard-fails if any .pc in the chain is missing, so gtk4's whole private
        # closure has to be on PKG_CONFIG_PATH, not just its public deps.
        ++ (with pkgs; [
          fontconfig
          freetype
          libepoxy
          libpng
          libxkbcommon
          pcre2
          util-linux
          wayland
          zlib
          fribidi
          libdatrie
          libthai
          libselinux
          libsepol
          expat
          brotli
          bzip2
          graphite2
          icu
          libffi
          libxml2
          lerc
          libdeflate
          xz
          zstd
        ])
        # Un-prefixed names: the `xorg.*` package set is deprecated.
        ++ (with pkgs; [
          libx11
          libxau
          libxcursor
          libxdmcp
          libxext
          libxfixes
          libxi
          libxinerama
          libxrandr
          libxrender
          libxcb
          xorgproto
        ]);

        # ruby-gnome gems build C extensions with extconf.rb + the pkg-config
        # gem; nixpkgs only ships gemConfig entries for the GTK3-era subset, so
        # the GTK4 gems get their build inputs declared here.
        rubyGnomeGem = _attrs: {
          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = gtkStack;
        };

        gemConfig = pkgs.defaultGemConfig // {
          gdk4 = rubyGnomeGem;
          gsk4 = rubyGnomeGem;
          gtk4 = rubyGnomeGem;
          graphene1 = rubyGnomeGem;
          adwaita = rubyGnomeGem;
          rsvg2 = rubyGnomeGem;
        };

        # `makeSearchPath` would take each package's *first* output, and glib's
        # first output is `bin`, which carries no typelibs — hence the explicit
        # `.out`. at-spi2-core is here for the Atk typelib.
        typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0"
          (map (drv: drv.out or drv) (gtkStack ++ [ pkgs.at-spi2-core ]));

        # nix/ and not the repo root: the root Gemfile is kettle-jem's
        # development bundle — rubocop, rspec, yard, the kettle-dev stack — and
        # must not end up in a packaged app's runtime closure. nix/Gemfile holds
        # the gemspec's runtime dependencies only.
        gems = pkgs.bundlerEnv {
          name = "sessions-gems";
          ruby = pkgs.ruby_3_4;
          inherit gemConfig;
          gemdir = ./nix;
        };

        # The launcher is whatever the gemspec installs into exe/. Reading the
        # directory keeps this flake generic: no name to keep in step by hand.
        launcher = builtins.head (builtins.attrNames (builtins.readDir ./exe));

        # The reverse-DNS application ID, which is also the basename of every
        # file in data/ that a desktop installs under that name.
        appId = "com.pojtinger.felicitas.Sessions";

        # Gtk::MediaFile plays the alarm through GtkMediaStream's GStreamer
        # backend, which looks for a `playbin3` element at construction time
        # and aborts the process when it cannot find one — so the alarm is
        # untestable, not merely silent, without these.
        gstStack = with pkgs.gst_all_1; [
          gstreamer
          gst-plugins-base
          gst-plugins-good
        ];

        gstPluginPath = pkgs.lib.makeSearchPath "lib/gstreamer-1.0" gstStack;

        # Optional directories: a port that has not grown translations or data
        # assets yet simply has none.
        optionalDirs = builtins.filter (d: builtins.pathExists (./. + "/${d}")) [
          "data"
          "po"
        ];
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "sessions";
          version = "0.1.0";
          src = ./.;

          # Deliberately no wrapGAppsHook4: glib's setup hook relocates
          # share/glib-2.0/schemas during fixup, after wrapGAppsHook4 has
          # computed its wrapper arguments, so a schema would end up somewhere
          # the wrapper never looks. The wrapper below is built by hand and
          # points at both the pre- and post-move paths.
          # gettext is build-time only: msgfmt compiles the catalogues and
          # merges the translated desktop/metainfo files, and nothing at
          # runtime calls it.
          nativeBuildInputs = [ pkgs.makeWrapper pkgs.gettext ];
          buildInputs = [ gems ] ++ gtkStack ++ gstStack;

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/sessions
            cp -r lib $out/share/sessions/
            for d in ${pkgs.lib.escapeShellArgs optionalDirs}; do
              cp -r "$d" $out/share/sessions/
            done
            # exe/ sits next to lib/ so the launcher's `require "sessions"`
            # resolves against the copied tree.
            install -Dm755 exe/${launcher} $out/share/sessions/exe/${launcher}

            # Compile any GSettings schema the port ships, from either
            # data/schemas/ or data/ itself.
            for d in data/schemas data; do
              if compgen -G "$d/*.gschema.xml" > /dev/null; then
                mkdir -p $out/share/glib-2.0/schemas
                cp "$d"/*.gschema.xml $out/share/glib-2.0/schemas/
                ${pkgs.glib.dev}/bin/glib-compile-schemas $out/share/glib-2.0/schemas
                break
              fi
            done

            # The desktop entry, AppStream metainfo and icons, where a desktop
            # looks for them. `rake gettext:data` regenerates the two
            # translated files from the .in templates and po/ first; a build
            # from a clean checkout installs the English templates.
            install -Dm644 data/${appId}.desktop \
              $out/share/applications/${appId}.desktop 2>/dev/null || \
              install -Dm644 data/${appId}.desktop.in \
                $out/share/applications/${appId}.desktop
            install -Dm644 data/${appId}.metainfo.xml \
              $out/share/metainfo/${appId}.metainfo.xml 2>/dev/null || \
              install -Dm644 data/${appId}.metainfo.xml.in \
                $out/share/metainfo/${appId}.metainfo.xml
            install -Dm644 data/${appId}.svg \
              $out/share/icons/hicolor/scalable/apps/${appId}.svg
            install -Dm644 data/${appId}-symbolic.svg \
              $out/share/icons/hicolor/symbolic/apps/${appId}-symbolic.svg

            # One compiled catalogue per language, in the layout gettext looks
            # for: share/locale/<lang>/LC_MESSAGES/<domain>.mo.
            while read -r lang; do
              [ -f "po/$lang.po" ] || continue
              install -d "$out/share/locale/$lang/LC_MESSAGES"
              ${pkgs.gettext}/bin/msgfmt -c --check-format \
                -o "$out/share/locale/$lang/LC_MESSAGES/sessions.mo" "po/$lang.po"
            done < po/LINGUAS

            # -rbundler/setup puts the bundled gems on the load path, and
            # GI_TYPELIB_PATH keeps GObject-Introspection from re-registering
            # types the cairo gem's C extension has already registered.
            makeWrapper ${gems.wrappedRuby}/bin/ruby $out/bin/${launcher} \
              --add-flags "-rbundler/setup" \
              --add-flags "-I$out/share/sessions/lib" \
              --add-flags "$out/share/sessions/exe/${launcher}" \
              --set GI_TYPELIB_PATH "${typelibPath}" \
              --set GST_PLUGIN_SYSTEM_PATH_1_0 "${gstPluginPath}" \
              --set SESSIONS_LOCALE_DIR "$out/share/locale" \
              --set SESSIONS_SCHEMA_DIR "$out/share/glib-2.0/schemas" \
              --prefix XDG_DATA_DIRS : "$out/share" \
              --prefix XDG_DATA_DIRS : "$out/share/gsettings-schemas/sessions-0.1.0" \
              --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}" \
              --prefix XDG_DATA_DIRS : "${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}" \
              --prefix XDG_DATA_DIRS : "${pkgs.adwaita-icon-theme}/share"

            runHook postInstall
          '';

          meta = {
            description = "A Ruby GTK4 / Libadwaita port of sessions";
            mainProgram = launcher;
            platforms = pkgs.lib.platforms.linux;
          };
        };

        apps.default = utils.lib.mkApp { drv = self.packages.${system}.default; };

        devShells.default = pkgs.mkShell {
          name = "sessions-devshell";

          packages = [
            gems
            gems.wrappedRuby
            pkgs.bundler
            pkgs.bundix
            pkgs.pkg-config
            pkgs.glib.dev
            pkgs.gettext
            pkgs.gsettings-desktop-schemas
            pkgs.adwaita-icon-theme
            # update-desktop-database, for `rake install_data`.
            pkgs.desktop-file-utils
            # Xvfb: gtk_init needs a display, so `require "gtk4"` raises
            # Gtk::InitError without one and nothing in the app can be driven.
            pkgs.xvfb-run
            # rspec, for the display-free half of the suite under spec/. The
            # gem bundle this flake builds has no rspec executable in it, so
            # `bundle exec rspec` reports "command not found"; this is the
            # binary the banner names.
            pkgs.rubyPackages_3_4.rspec
          ] ++ gtkStack ++ gstStack;

          # Icons, GSettings schemas and the GTK portal all resolve through
          # XDG_DATA_DIRS; without these the window opens with blank icons.
          shellHook = ''
            # glib's share/ is here for share/gettext/its/gschema.its, which
            # is the ITS rule `rake gettext:pot` needs to extract the
            # schema's summary and description — gettext ships metainfo.its
            # but not that one.
            export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}:${pkgs.adwaita-icon-theme}/share:${pkgs.glib}/share:$XDG_DATA_DIRS"
            export GI_TYPELIB_PATH="${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"

            # bundler and bundix each export their own GEM_PATH, and a
            # GEM_PATH in the environment *replaces* the wrapped ruby's own
            # search path rather than adding to it — so without this line
            # `ruby -e 'require "gtk4"'` in the devshell fails with a
            # LoadError even though the gem is installed. Prepending the app's
            # gem directory restores it for plain `ruby` as well as `bundle
            # exec`.
            export GEM_PATH="${gems}/${pkgs.ruby_3_4.gemPath}''${GEM_PATH:+:$GEM_PATH}"

            export GST_PLUGIN_SYSTEM_PATH_1_0="${gstPluginPath}''${GST_PLUGIN_SYSTEM_PATH_1_0:+:$GST_PLUGIN_SYSTEM_PATH_1_0}"

            # The GSettings schema this port ships, so `gsettings get` and
            # Gio::Settings resolve it from a checkout. `rake schema:compile`
            # writes gschemas.compiled next to it.
            for d in data/schemas data; do
              if [ -n "$(echo "$d"/*.gschema.xml 2>/dev/null)" ] && [ -e "$(echo "$d"/*.gschema.xml | cut -d' ' -f1)" ]; then
                export GSETTINGS_SCHEMA_DIR="$PWD/$d"
                break
              fi
            done
            unset BUNDLE_GEMFILE BUNDLE_FROZEN

            # RUBYLIB is what makes `ruby exe/sessions` and `rspec` work from a
            # checkout: lib/ is not on the load path otherwise, and the specs
            # require the port by name rather than by relative path.
            export RUBYLIB="$PWD/lib''${RUBYLIB:+:$RUBYLIB}"

            echo "sessions devshell — ruby $(ruby -e 'print RUBY_VERSION')"
            echo "run the app:   xvfb-run -a ruby exe/sessions"
            echo "drive the app: xvfb-run -a ruby test/drive_main_window.rb"
            echo "drive German:  xvfb-run -a ruby test/drive_translations.rb"
            echo "run the specs: rspec --options /dev/null --require spec_helper --format progress spec"
          '';
        };
      });
}

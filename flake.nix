{
  description = "Rodin Platform 3.9 (Event-B IDE)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      version = "3.9.0.202406100806-9b87fe13d";

      # Libraries SWT/GTK load at runtime via dlopen; autoPatchelf can't see those.
      runtimeLibs = with pkgs; [
        glib
        gtk3
        cairo
        pango
        gdk-pixbuf
        atk
        libsecret
        webkitgtk_4_1
        xorg.libX11
        xorg.libXtst
        xorg.libXxf86vm
        libGL
        zlib
      ];

      rodin = pkgs.stdenv.mkDerivation {
        pname = "rodin";
        inherit version;

        src = pkgs.fetchurl {
          url = "mirror://sourceforge/rodin-b-sharp/Core_Rodin_Platform/3.9/rodin-${version}-linux.gtk.x86_64.tar.gz";
          hash = "sha256-6ICe6JgBetGtT+NU/l14Z0J+LVaNwFH6L6QzjD9Bfnk=";
        };

        nativeBuildInputs = with pkgs; [
          autoPatchelfHook
          makeWrapper
          copyDesktopItems
        ];
        buildInputs = runtimeLibs ++ [ pkgs.stdenv.cc.cc.lib ];

        # Bundled JRE / plugin natives may reference optional libs we don't need.
        autoPatchelfIgnoreMissingDeps = true;
        dontStrip = true;

        installPhase = ''
          runHook preInstall

          mkdir -p $out/opt/rodin $out/bin
          cp -r . $out/opt/rodin

          makeWrapper $out/opt/rodin/rodin $out/bin/rodin \
            --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath runtimeLibs} \
            --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.jdk17 ]} \
            --set-default GDK_BACKEND x11 \
            --prefix XDG_DATA_DIRS : ${pkgs.glib.getSchemaDataDirPath pkgs.gtk3} \
            --prefix XDG_DATA_DIRS : ${pkgs.glib.getSchemaDataDirPath pkgs.gsettings-desktop-schemas} \
            --add-flags "-vm ${pkgs.jdk17}/bin/java"

          if [ -f $out/opt/rodin/icon.xpm ]; then
            install -Dm644 $out/opt/rodin/icon.xpm $out/share/pixmaps/rodin.xpm
          fi

          runHook postInstall
        '';

        desktopItems = [
          (pkgs.makeDesktopItem {
            name = "rodin";
            exec = "rodin";
            icon = "rodin";
            desktopName = "Rodin";
            comment = "Event-B modelling and proof IDE";
            categories = [ "Development" "IDE" ];
          })
        ];

        meta = {
          description = "Eclipse-based IDE for Event-B modelling and formal proof";
          homepage = "https://www.event-b.org/";
          license = pkgs.lib.licenses.epl10;
          platforms = [ "x86_64-linux" ];
          mainProgram = "rodin";
        };
      };
    in
    {
      packages.${system}.default = rodin;

      apps.${system}.default = {
        type = "app";
        program = "${rodin}/bin/rodin";
      };
    };
}

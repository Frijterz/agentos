# Boot splash: the agentOS mark (a planet with an orbit and a satellite, like the
# wallpaper) glowing slowly on near-black, with the wordmark and a LUKS passphrase
# prompt in the lock screen's style. A Plymouth "script" theme; the logo comes from
# themes/agentos-logo.nix (SVG rendered at build time), so the repo holds no binaries.
# Plymouth itself reads the passphrase; this theme only draws it, so even a drawing bug
# can't stop you from unlocking. Older generations in the boot menu keep the old splash.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = config.lib.stylix.colors;
  hex = base: "#${c.${base}}";
  # Plymouth wants colours as 0–1 floats.
  rgb =
    base:
    lib.concatMapStringsSep ", " (ch: toString (lib.toInt c."${base}-rgb-${ch}" / 255.0)) [
      "r"
      "g"
      "b"
    ];

  fonts = pkgs.nerd-fonts.jetbrains-mono;
  fontDir = "${fonts}/share/fonts/truetype/NerdFonts/JetBrainsMono";

  logo = import ./themes/agentos-logo.nix {
    inherit pkgs;
    colors = config.lib.stylix.colors;
  };

  script = pkgs.writeText "agentos.script" ''
    // agentOS boot splash (see modules/nixos/splash.nix).
    Window.SetBackgroundTopColor(${rgb "base00"});
    Window.SetBackgroundBottomColor(${rgb "base00"});

    W = Window.GetWidth();
    H = Window.GetHeight();
    cx = Window.GetX() + W / 2;
    cy = Window.GetY() + H / 2 - 90;

    mark_image = Image("mark.png");
    glow_image = Image("glow.png");
    word_image = Image("word.png");
    box_image = Image("box.png");

    glow = Sprite(glow_image);
    glow.SetPosition(cx - glow_image.GetWidth() / 2, cy - glow_image.GetHeight() / 2, 1);
    mark = Sprite(mark_image);
    mark.SetPosition(cx - mark_image.GetWidth() / 2, cy - mark_image.GetHeight() / 2, 2);
    word = Sprite(word_image);
    word.SetPosition(cx - word_image.GetWidth() / 2, cy + 125, 2);
    word.SetOpacity(0);

    // Called ~50 times a second: one slow breath of the glow every 3.2 s.
    frame = 0;
    fun refresh_callback() {
      global.frame++;
      breath = (1 - Math.Cos(global.frame / 160 * 2 * Math.Pi)) / 2;
      glow.SetOpacity(0.12 + 0.63 * breath);
      mark.SetOpacity(0.78 + 0.22 * breath);
      if (global.frame < 75)
        word.SetOpacity(global.frame / 75);
      else
        word.SetOpacity(1);
    }
    Plymouth.SetRefreshFunction(refresh_callback);

    fun text(str, r, g, b, a, size) {
      return Image.Text(str, r, g, b, a, "JetBrainsMono Nerd Font " + size);
    }

    // Passphrase prompt (LUKS): header, a square field with dots, the system's prompt.
    header_image = text("MISSION CONTROL  ·  AUTHORIZATION REQUIRED", ${rgb "base0D"}, 0.75, 11);
    fun hide_password() {
      if (global.pw_header) global.pw_header.SetOpacity(0);
      if (global.pw_box) global.pw_box.SetOpacity(0);
      if (global.pw_dots) global.pw_dots.SetOpacity(0);
      if (global.pw_prompt) global.pw_prompt.SetOpacity(0);
    }
    fun display_password_callback(prompt, bullets) {
      top = cy + 215;
      global.pw_header = Sprite(header_image);
      global.pw_header.SetPosition(cx - header_image.GetWidth() / 2, top, 3);
      global.pw_box = Sprite(box_image);
      global.pw_box.SetPosition(cx - box_image.GetWidth() / 2, top + 30, 3);

      if (bullets > 0) {
        dots = "";
        i = 0;
        while (i < bullets && i < 22) {
          dots = dots + "• ";
          i++;
        }
        dots_image = text(dots, ${rgb "base05"}, 1, 14);
      } else {
        dots_image = text("ENTER PASSPHRASE", ${rgb "base04"}, 0.8, 12);
      }
      global.pw_dots = Sprite(dots_image);
      global.pw_dots.SetPosition(cx - dots_image.GetWidth() / 2, top + 30 + (box_image.GetHeight() - dots_image.GetHeight()) / 2, 4);

      prompt_image = text(prompt, ${rgb "base04"}, 0.6, 10);
      global.pw_prompt = Sprite(prompt_image);
      global.pw_prompt.SetPosition(cx - prompt_image.GetWidth() / 2, top + 30 + box_image.GetHeight() + 14, 3);
    }
    fun display_normal_callback() {
      hide_password();
    }
    Plymouth.SetDisplayPasswordFunction(display_password_callback);
    Plymouth.SetDisplayNormalFunction(display_normal_callback);

    // Status messages (e.g. errors) at the bottom.
    fun message_callback(msg) {
      msg_image = text(msg, ${rgb "base04"}, 0.7, 10);
      global.message = Sprite(msg_image);
      global.message.SetPosition(cx - msg_image.GetWidth() / 2, Window.GetY() + H - 70, 3);
    }
    Plymouth.SetMessageFunction(message_callback);
  '';

  theme = pkgs.runCommand "agentos-plymouth-theme" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    dir=$out/share/plymouth/themes/agentos
    mkdir -p $dir
    cd $dir
    cp ${logo}/mark.png ${logo}/word.png ${logo}/glow.png .
    magick -size 340x46 xc:'${hex "base01"}' -fill none -stroke '${hex "base0D"}' -strokewidth 2 -draw 'rectangle 1,1 338,44' box.png
    cp ${script} agentos.script
    cat > agentos.plymouth <<EOF
    [Plymouth Theme]
    Name=agentOS
    Description=agentOS Mission Control boot splash
    ModuleName=script

    [script]
    ImageDir=$dir
    ScriptFile=$dir/agentos.script
    EOF
  '';
in
{
  stylix.targets.plymouth.enable = false;
  boot.plymouth = {
    theme = "agentos";
    themePackages = [ theme ];
    # Image.Text draws with this font (the rest of the system uses it too).
    font = "${fontDir}/JetBrainsMonoNerdFont-Regular.ttf";
  };
}

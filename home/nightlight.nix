# Night light: gammastep warms the screen after sunset and fades back after sunrise,
# following the sun for Veghel (city-level coordinates, same place as home/weather.nix),
# so there's no schedule to keep up with the seasons. The change is a slow fade over
# twilight, not a jump. Super+N pauses or resumes it (hyprland.lua).
{ ... }:
{
  services.gammastep = {
    enable = true;
    provider = "manual";
    latitude = 51.6;
    longitude = 5.5;
    temperature = {
      day = 6500; # neutral: true colours during the day
      night = 3800;
    };
    settings.general = {
      adjustment-method = "wayland";
      fade = 1; # fade on pause / resume too
    };
  };
}

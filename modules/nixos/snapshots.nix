# NixOS generations roll back the *system*; snapper protects your *files* in /home.
# Browse or restore with: snapper -c home list / snapper -c home undochange <a>..<b>
{ vars, ... }:
{
  services.snapper = {
    snapshotInterval = "hourly";
    cleanupInterval = "1d";
    configs.home = {
      SUBVOLUME = "/home";
      ALLOW_USERS = [ vars.user ];
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_LIMIT_HOURLY = 12;
      TIMELINE_LIMIT_DAILY = 7;
      TIMELINE_LIMIT_WEEKLY = 4;
      TIMELINE_LIMIT_MONTHLY = 3;
      TIMELINE_LIMIT_YEARLY = 0;
      # "number" snapshots: taken before each Apply in the Claude panel (agentos-switch).
      NUMBER_CLEANUP = true;
      NUMBER_LIMIT = "10";
    };
  };

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };
}

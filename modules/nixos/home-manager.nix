{ inputs, vars, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # If a file Home Manager wants to manage already exists, move it aside instead of failing.
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs vars; };
    users.${vars.user} = import ../../home;
  };
}

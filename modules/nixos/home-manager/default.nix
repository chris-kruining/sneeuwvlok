{ ... }:
{
  config = {
    home-manager.backupFileExtension = "homeManagerBackup";
    # Plasma rewrites files like mimeapps.list as plain files, a second backup would otherwise fail the whole activation
    home-manager.overwriteBackup = true;
  };
}

# Backup

Your home folder is backed up daily to Cloudflare R2 with restic
(`modules/nixos/backup.nix`). It is encrypted on the laptop before upload, so without
the restic password the bucket is unreadable, to Cloudflare as well as to anyone else.
The health watcher warns when the last good backup is more than 3 days old.

**Keep the restic password and the R2 keys in Bitwarden.** If the laptop is gone, they
are the only way back in; the copy on the laptop is gone with it.

## One-time setup

1. **Bucket.** In the Cloudflare dashboard: R2 → Create bucket, name it `agentos-backup`.
2. **Key.** R2 → Manage API tokens → Create API token: *Object Read & Write*, only
   for that bucket. Note the Access Key ID, the Secret Access Key and your account ID
   (it's part of the S3 endpoint, `https://<account-id>.r2.cloudflarestorage.com`).
3. **Bitwarden.** Make an item "agentos backup": a generated password of 32+ characters
   (that's the restic password), and the two R2 keys in its notes.
4. **The secrets on the laptop.** In a real terminal (not in Claude, so the keys stay
   out of any chat). The folder exists once the backup module is applied.

   ```sh
   sudo -e /var/lib/agentos/backup/env
   ```
   with these four lines:
   ```sh
   RESTIC_REPOSITORY=s3:https://<account-id>.r2.cloudflarestorage.com/agentos-backup
   AWS_ACCESS_KEY_ID=<access key id>
   AWS_SECRET_ACCESS_KEY=<secret access key>
   AWS_DEFAULT_REGION=auto
   ```
   and then the password, straight from Bitwarden:
   ```sh
   rbw get "agentos backup" | sudo tee /var/lib/agentos/backup/password >/dev/null
   ```
5. **First backup** (it also creates the repository in the bucket):
   ```sh
   sudo systemctl start restic-backups-home
   journalctl -u restic-backups-home -e
   sudo restic-home snapshots
   ```

## Getting files back

```sh
sudo restic-home snapshots                          # what's there
sudo restic-home ls latest /home/frijterz/Pictures  # browse a snapshot
sudo restic-home restore latest --target /tmp/restore --include /home/frijterz/Pictures
sudo restic-home mount /mnt                         # browse all snapshots as folders
```

For a recent mistake, snapper is quicker (`snapper -c home list`): it's local and
hourly. restic is for when the laptop itself is lost or broken.

On a new machine: install restic, fill in the same four variables plus
`RESTIC_PASSWORD` from Bitwarden, and `restic restore latest --target /`.

## What's in it

All of `/home/frijterz` except caches (`.cache`, Chromium's caches, `.npm`,
`node_modules`) and the trash. Kept: 7 daily, 4 weekly and 6 monthly snapshots.
Unchanged files are stored once, so extra snapshots cost only what changed.
Check the size with `sudo restic-home stats --mode raw-data`.

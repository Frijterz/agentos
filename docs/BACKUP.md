# Backup

Your home folder is backed up daily to Cloudflare R2 with restic
(`modules/nixos/backup.nix`). It is encrypted on the laptop before upload, so without
the restic password the bucket is unreadable, to Cloudflare as well as to anyone else.
The health watcher warns when the last good backup is more than 3 days old.

**Keep a copy of the restic password off the laptop.** Without it the backup can't be
opened, by you either; if the laptop is gone, the copy on it is gone with it.

## One-time setup

1. **Bucket.** In the Cloudflare dashboard: R2 → Create bucket, name it `agentos-backup`,
   jurisdiction *European Union* (the data stays in the EU).
2. **Key.** R2 → Manage API tokens → Create API token: *Object Read & Write*, only
   for that bucket. You need the **Access Key ID** (32 characters) and the **Secret
   Access Key** (64), not the "Token value". The account ID is in the dashboard URL.
3. **The secrets on the laptop.** In a real terminal (not in Claude, so the keys stay
   out of any chat). The folder exists once the backup module is applied.

   ```sh
   sudo -e /var/lib/agentos/backup/env
   ```
   with these four lines:
   ```sh
   RESTIC_REPOSITORY=s3:https://<account-id>.eu.r2.cloudflarestorage.com/agentos-backup
   AWS_ACCESS_KEY_ID=<access key id>
   AWS_SECRET_ACCESS_KEY=<secret access key>
   AWS_DEFAULT_REGION=auto
   ```
   `s3:` must be there and lowercase; `.eu.` is because the bucket is in the EU
   jurisdiction (leave it out for a bucket without one).

   Then generate the restic password, and copy it somewhere off the laptop:
   ```sh
   head -c 32 /dev/urandom | base64 | sudo tee /var/lib/agentos/backup/password >/dev/null
   sudo cat /var/lib/agentos/backup/password
   ```
4. **First backup** (it also creates the repository in the bucket):
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
`RESTIC_PASSWORD` from your off-laptop copy, and `restic restore latest --target /`.

## When it fails

`journalctl -u restic-backups-home -e` shows why:

- *invalid backend*: `RESTIC_REPOSITORY` doesn't start with a lowercase `s3:`.
- *an empty password is not allowed*: the password file is empty.
- *Access Denied*: the R2 token can't write to this bucket. Check that it is *Object
  Read & Write* and covers `agentos-backup`.
- *The specified bucket does not exist*: the bucket name, or `.eu.` in the address,
  doesn't match the bucket.

Being offline is fine: a failed run retries every 30 minutes, and the health watcher only
warns once there's been no good backup for 3 days.

## What's in it

All of `/home/frijterz` except caches (`.cache`, Chromium's caches, `.npm`,
`node_modules`) and the trash. Kept: 7 daily, 4 weekly and 6 monthly snapshots.
Unchanged files are stored once, so extra snapshots cost only what changed.
Check the size with `sudo restic-home stats --mode raw-data`.

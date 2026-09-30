# 0. Initial setup: moving the files onto the NAS

This gets the project folder onto the Synology so you can fill in `.env` and start it. No Git is needed on the NAS.

Do the "Before you start: DSM setup" steps in [`01-host-user.md`](01-host-user.md) first, so the `docker` and `data` shared folders exist.

## What you're aiming for

When you're done, this file must exist on the NAS at exactly this path:

```text
/volume1/docker/arr-stack/docker-compose.yml
```

(If your shared folders are on another volume, `volume1` will be `volume2`, and so on.) The most common mistake is one extra folder level, such as `/volume1/docker/arr-stack/arr-stack-deploy-main/docker-compose.yml`. The compose file must sit directly inside `arr-stack`.

## 1. Get the files onto your computer

Pick one:

- **From GitHub (private repo):** sign in to <https://github.com/James-Jaffray/arr-stack-deploy>, click the green **Code** button > **Download ZIP**. Unzip it. You get a folder named `arr-stack-deploy-main`.
- **From your working copy:** use the folder you already have (`F:\ArrStack`).

Either way, **do not take along** a `.env` file or a `config/` or `data/` folder if they exist. They belong to another machine, and `.env` contains VPN secrets. The ZIP doesn't include them.

Rename the folder to **`arr-stack`**.

## 2. Copy it to the NAS

**Option A: through Windows File Explorer (easiest for a big folder)**

1. Open File Explorer, click the address bar, type `\\192.168.1.20\docker` (use your NAS's IP) and press Enter.
2. If asked to sign in, use the `arr` user's DSM username and password. (Files copied this way are owned by that user, which is what you want.) Tick "Remember my credentials" only on your own PC.
3. Drag the `arr-stack` folder into the `docker` share.

If the share doesn't open, in DSM check Control Panel > File Services > SMB is enabled, and that the `arr` user has permission on the `docker` shared folder.

**Option B: through DSM File Station (in the browser)**

1. Open File Station, go into the `docker` shared folder.
2. Click **Upload** > **Upload - Skip** (or drag the folder in).
3. Choose the `arr-stack` folder from your computer.

## 3. Check it landed correctly

In File Station open `docker/arr-stack`. You should see these directly inside it:

```text
docker-compose.yml   .env.example   setup.sh   README.md
scripts/   instructions/
```

If you see a single `arr-stack` (or `arr-stack-deploy-main`) folder inside instead, move its contents up one level. Files whose names start with a dot (`.env.example`) may be hidden in File Station and Explorer; that's normal.

Or [SSH in](01-host-user.md#how-to-ssh-into-the-nas) and check:

```sh
ls -a /volume1/docker/arr-stack
```

## 4. Create the `.env` file

`.env` holds your secrets, so create it on the NAS side from the template. Pick one:

**Option A: edit it on your computer, then upload it**

1. In your unzipped folder, copy `.env.example` and rename the copy to **`.env`**. Windows hides file extensions by default; turn on View > Show > File name extensions so it doesn't end up called `.env.txt`.
2. Fill it in with Notepad, following the guides in this folder (`01` to `06`).
3. Upload `.env` to `docker/arr-stack` the same way as in step 2.
4. **Delete the copy on your computer**, and empty the Recycle Bin, since it holds your VPN key.

If Notepad saves it with Windows line endings, that's fine: `setup.sh` detects this and offers to fix it.

**Option B: create it on the NAS over SSH**

```sh
cd /volume1/docker/arr-stack
sudo cp .env.example .env
sudo vi .env
```

`vi` is awkward if you haven't used it: press `i` to type, `Esc` then `:wq` and Enter to save, or `Esc` then `:q!` to quit without saving. Option A is easier for a first-timer.

## 5. Next

[SSH in](01-host-user.md#how-to-ssh-into-the-nas) and run the checks from the folder:

```sh
cd /volume1/docker/arr-stack
sudo sh setup.sh --check     # reports anything still wrong in .env
sudo sh setup.sh             # creates folders and sets ownership
```

Use `sh setup.sh` rather than `./setup.sh`, because copying from Windows can lose the "executable" flag. Then continue with the Synology section of the main [README](../README.md) to start the stack.

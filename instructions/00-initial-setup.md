# 0. Initial setup: preparing the NAS and moving the files over

This prepares the Synology (Container Manager, the `arr` user, shared folders, SSH) and gets the project folder onto it. No Git is needed on the NAS. Do it before the `.env` guides (`01` to `06`), which need the `arr` user this page creates.

This is written for DSM 7.2+. Menu names may differ slightly between DSM versions.

## What you're aiming for

When you're done, this file must exist on the NAS at exactly this path:

```text
/volume1/docker/arr-stack/docker-compose.yml
```

(If your shared folders are on another volume, `volume1` will be `volume2`, and so on. To confirm: File Station, right-click a shared folder > Properties > "Location".) The most common mistake is one extra folder level, such as `/volume1/docker/arr-stack/arr-stack-deploy-main/docker-compose.yml`. The compose file must sit directly inside `arr-stack`.

## 1. Prepare DSM

**a. Install Container Manager**
Package Center > search **Container Manager** > Install. This is what runs the containers. Installing it usually also creates a shared folder called `docker`.

**b. Create the two shared folders**
Control Panel > Shared Folder > **Create**.
- Name `docker` (skip this if it already exists after step a). Leave the location on your main volume.
- Name `data`, on the **same volume** as `docker`. This will hold `torrents/` and `media/`; it has to be one volume so downloads can be hardlinked instead of copied.
- Accept the defaults on the remaining screens.

Make the folders first: the next step lists the ones that exist.

**c. Create the dedicated `arr` user**
Control Panel > User & Group > **Create** > Create user.
1. Name: `arr`. Set a password and keep it (you'll use it to copy files in step 4).
2. **Join groups:** leave it in the default `users` group.
3. **Assign shared folder permissions:** tick **Read/Write** for both `docker` and `data`.
4. **Assign application permissions:** leave **SMB** allowed (Windows File Explorer needs it to copy files). You can deny the others.
5. Finish the wizard.

The apps will run as this user, so their files are owned by it rather than by your admin account. Its numeric IDs are what you'll put in `PUID` and `PGID` in `01-host-user.md`.

## 2. How to SSH into the NAS

SSH lets you type commands on the NAS from another computer. You need it to look up `arr`'s IDs and to run `setup.sh`. It's off by default; turn it on for now and off again when you've finished.

**Turn it on (in DSM, in your browser)**
1. Control Panel > Terminal & SNMP > **Terminal** tab.
2. Tick **Enable SSH service**. Leave the port at `22` and click **Apply**.

**Find the NAS's IP address**
- DSM: Control Panel > Network > Network Interface, select your connection, and read the IP address (for example `192.168.1.20`). This is also the address you use in the browser for DSM.
- Or open <https://find.synology.com> from a computer on the same network.

**Connect from a computer on the same network**
1. On Windows open **Terminal** or **PowerShell**. (On Mac or Linux open Terminal.) Windows 10 and 11 already include `ssh`.
2. Run the command below, using your **DSM administrator account** name and the NAS IP:

   ```sh
   ssh yourAdminName@192.168.1.20
   ```

   On DSM 7 only accounts in the **administrators** group can use SSH, so the new `arr` user can't log in this way. That's fine: you log in as your admin account and use it to look up `arr`'s IDs.
3. The first time, it says it can't verify the host and asks "Are you sure you want to continue connecting?". Type `yes` and press Enter.
4. Enter your DSM password. **Nothing appears as you type**; that's normal. Press Enter.
5. When you see a prompt such as `yourAdminName@NASName:~$`, you're in. Type commands there.
6. Commands that start with `sudo` ask for your password again. Type it (again nothing shows) and press Enter.
7. Type `exit` to disconnect.

**If it doesn't connect:** check the IP, check you're on the same network as the NAS, and check SSH is ticked and applied. "Connection refused" usually means SSH is still off.

**When finished with the whole setup:** turn **Enable SSH service** off again in the same DSM screen.

## 3. Get the files onto your computer

Pick one:

- **From GitHub (private repo):** sign in to <https://github.com/James-Jaffray/arr-stack-deploy>, click the green **Code** button > **Download ZIP**. Unzip it. You get a folder named `arr-stack-deploy-main`.
- **From your working copy:** use the folder you already have (`F:\ArrStack`).

Either way, **do not take along** a `.env` file or a `config/` or `data/` folder if they exist. They belong to another machine, and `.env` contains VPN secrets. The ZIP doesn't include them.

Rename the folder to **`arr-stack`**.

## 4. Copy it to the NAS

**Option A: through Windows File Explorer (easiest for a big folder)**

1. Open File Explorer, click the address bar, type `\\192.168.1.20\docker` (use your NAS's IP) and press Enter.
2. If asked to sign in, use the `arr` user's DSM username and password. (Files copied this way are owned by that user, which is what you want.) Tick "Remember my credentials" only on your own PC.
3. Drag the `arr-stack` folder into the `docker` share.

If the share doesn't open, in DSM check Control Panel > File Services > SMB is enabled, and that the `arr` user has SMB permission and Read/Write on the `docker` shared folder (step 1c).

**Option B: through DSM File Station (in the browser)**

1. Open File Station, go into the `docker` shared folder.
2. Click **Upload** > **Upload - Skip** (or drag the folder in).
3. Choose the `arr-stack` folder from your computer.

## 5. Check it landed correctly

In File Station open `docker/arr-stack`. You should see these directly inside it:

```text
docker-compose.yml   .env.example   setup.sh   README.md
scripts/   instructions/
```

If you see a single `arr-stack` (or `arr-stack-deploy-main`) folder inside instead, move its contents up one level. Files whose names start with a dot (`.env.example`) may be hidden in File Station and Explorer; that's normal.

Or [SSH in](#2-how-to-ssh-into-the-nas) and check:

```sh
ls -a /volume1/docker/arr-stack
```

## 6. Create the `.env` file

`.env` holds your secrets. Create it from the template once you've read the guides for its values (`01` to `06`); you can come back to this step afterwards. Pick one:

**Option A: edit it on your computer, then upload it**

1. In your unzipped folder, copy `.env.example` and rename the copy to **`.env`**. Windows hides file extensions by default; turn on View > Show > File name extensions so it doesn't end up called `.env.txt`.
2. Fill it in with Notepad, following the guides in this folder (`01` to `06`).
3. Upload `.env` to `docker/arr-stack` the same way as in step 4.
4. **Delete the copy on your computer**, and empty the Recycle Bin, since it holds your VPN key.

If Notepad saves it with Windows line endings, that's fine: `setup.sh` detects this and offers to fix it.

**Option B: create it on the NAS over SSH**

```sh
cd /volume1/docker/arr-stack
sudo cp .env.example .env
sudo vi .env
```

`vi` is awkward if you haven't used it: press `i` to type, `Esc` then `:wq` and Enter to save, or `Esc` then `:q!` to quit without saving. Option A is easier for a first-timer.

## 7. Next

Continue with [`01-host-user.md`](01-host-user.md) to work out the values for `.env`. Once `.env` is on the NAS, [SSH in](#2-how-to-ssh-into-the-nas) and run the checks from the folder:

```sh
cd /volume1/docker/arr-stack
sudo sh setup.sh --check     # reports anything still wrong in .env
sudo sh setup.sh             # creates folders and sets ownership
```

Use `sh setup.sh` rather than `./setup.sh`, because copying from Windows can lose the "executable" flag. Then continue with the Synology section of the main [README](../README.md) to start the stack.

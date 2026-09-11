# Wi-Fi and file transfer

Enable Wi-Fi under `START` → `Network Settings`, then use `Connect Wi-Fi` to
select an SSID and enter its password. After connecting, read the device IP
from `INFORMATION`. Turning Wi-Fi off may take a few seconds while services stop.

Factory credentials are below. Change the password after initial setup.

| Method | Address / port | User | Password | Purpose |
| --- | --- | --- | --- | --- |
| SSH | Bubble IP / 22 | `root` | `plumos` | Shell |
| SFTP | Bubble IP / 22 | `root` | `plumos` | Secure file transfer |
| FTP | Bubble IP / 21 | anonymous | none | Simple file transfer |
| Samba | `\\<IP>\SDCARD` | `plumos` | `plumos` | Windows/macOS share |

All three file-transfer routes expose the user area. Put ROMs in
`Roms/<system>/` and BIOS files in `BIOS/`, then refresh the game list.

- Change factory credentials before joining an untrusted network.
- There is no ADB menu; USB is charge-only.
- Check the LAN, device IP and client firewall when a route is unreachable.
- After an interrupted large transfer, verify its size or hash before retrying.

# Description

My work laptop, reasoning for the name being the following chain of thought:  
**Orome -> the huntsman -> hunting means leaving home -> work laptop travels with me**

## Menicon device certificate

Menicon's tenant sits behind HENNGE Access Control (Cybertrust DeviceiD) in front of the normal Microsoft login: after
entering the email, it redirects to a HENNGE page with a "Log in with Certificate" button. That certificate is per device and
has to be issued by Menicon IT, for orome's wifi and ethernet MAC addresses (`dc:97:ba:a3:5d:90`, `d0:76:0c:58:97:03`).

Their mail says to run Cybertrust's Windows-only "DeviceiD Importer" with a certificate identifier
(`DiDh|G4h|DeviceiD_HDE_UCS|<request id>`). That importer only does a few form posts to
`https://cybertrust.deviceid.ne.jp/pages/ee/`, which curl does just as well, within the 14 days the mail gives:

1. `importer/newcert/login` with `SITE_ID`, `cert_policy` (`G4h/DeviceiD_HDE_UCS`) and `req_id`, keep its cookies
2. `importer/newcert/fetch` with those cookies, `user_id` (the uppercase sha1 of each uppercase `AA:BB:..` MAC, joined
   by `|`), `user_password=cybertrust`, a pin of choice as `PKCS12_PIN` and `PKCS12_PIN_CONF`, the same three fields,
   `ERR_PAGE=errorDownloadKeyforImporter.jsp` and `ERR_PAGE_SESSION=sessionInvalidforImporter.jsp`. It answers with
   the `.p12`, encrypted with that pin (legacy RC2/3DES, `openssl -legacy` reads it)
3. `importer/newcert/result` with the login's fields, `user_id`, `user_password` and `import_result=0`, so the portal
   marks it installed

The server's chain isn't in the default bundle, add its intermediate
(`http://crl.cybertrust.ne.jp/SureServer/evcag3/evcag3.crt`) with `--cacert`.

Helium (Chromium) reads client certificates from its NSS database, so it's imported there. Repack the `.p12` without a
password and with `menicon-device-cert` as its name (NSS takes the nickname from the file), then encrypt it:

```sh
openssl pkcs12 -legacy -in fetched.p12 -nodes | openssl pkcs12 -export -passout pass: -name menicon-device-cert -out cert.p12
sops encrypt --filename-override systems/x86_64-linux/orome/menicon-device-cert.sops \
  --input-type binary --output-type binary cert.p12 > systems/x86_64-linux/orome/menicon-device-cert.sops
```

`menicon/device_cert_password` stays empty for a file without a password.

Then rebuild (`just machine update orome`, or `sudo nixos-rebuild switch --flake .#orome` on orome itself). The next
home-manager activation imports the certificate into `~/.pki/nssdb` under the nickname `menicon-device-cert`,
replacing any earlier import of the same name so re-running this (a renewed cert, say) doesn't pile up duplicates.

- Worked: `certutil -L -d sql:$HOME/.pki/nssdb` lists `menicon-device-cert`, and the HENNGE login's "Log in with
  Certificate" button offers it.
- Nothing listed: check `home-manager switch` output (or `journalctl --user -u home-manager-chris.service`) for the
  activation script's own errors, most likely a wrong password or a `.pfx` that didn't encrypt as binary.

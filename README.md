# Chrome Local State US Switch

Run this on macOS to force quit Google Chrome, update Chrome's `Local State`
country fields to `us`, mark `is_glic_eligible` as `true`, save the file, and
open Chrome again.

```sh
./set_chrome_us.sh
```

The script creates a timestamped backup next to the original file before
writing changes.

To edit a different Chrome profile data directory or test file, pass the Local
State path explicitly:

```sh
./set_chrome_us.sh "/path/to/Local State"
```

# Use-case:
The luau language treats only configurations provided via Roblox's fflags as canon, but has not provided a way to allow users/embedders of the luau binary to run it as such by default or with a preset; without any `--fflags=`, the luau binary sets its own default list of fflags to true.

This mismatch has caused confusion with luau's users enough times, including users communicating with the luau team, warranting the decision to create this small tool.

The lack of documentation in stating or confirming this standard was found to be resolvable upon looking in [luau-lang's playground repo](https://github.com/luau-lang/playground/blob/b0afa61dcf78a12c18d7ab67c44d4a6482aefdec/src/lib/luau/wasm.ts#L25).

# How to Use
Ensure you have the following dependencies:
- `curl` for pulling live roblox fflags from the canonical URL
- `jq` for parsing/filtering the json results from prior `curl`
- `luau` for running the luau binary itself.

Execution permissions are required; if permission is denied, run `chmod +x ./studioinator.sh`.

Then, run `./studioinator.sh`, passing arguments the same way you would into the luau binary.

## Contributions
Contributions are welcome to improve the utility of this tool. Some current examples would be improving how fflags can be provided, and specifying which luau binary to run, such as `luau-analyze`.

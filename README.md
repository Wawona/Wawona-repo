# Wawona Repo

This is the source for [repo.wawona.io](https://repo.wawona.io).

## Developer Notes

To update the repository indices after adding new `.deb` files:

```bash
nix run .#update
```

The site uses `index.html` as the primary landing page for users.

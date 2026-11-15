# Inkstead app

The Inkstead app can connect to a Sumi site so it knows which repository to edit, where posts and media live and which posting categories or syndication providers are available. You can set this up during `sumi init`, add it to `sumi.json` later or leave it to be detected automatically.

## Configuring the connection

Add an `inkstead` section to `sumi.json`:

```json
{
  "inkstead": {
    "provider": "github",
    "repository": "owner/site",
    "branch": "main",
    "categories": ["Notes", "Photos"]
  }
}
```

The keys:

| Key | What it does |
| --- | --- |
| `provider` | Where the repository lives: `github`, `gitlab` or `forgejo` |
| `repository` | The repository owner and name, such as `owner/site` |
| `branch` | The branch to edit; defaults to the branch detected by CI when available |
| `instanceUrl` | The server address, useful for Forgejo or self-managed GitLab instances |
| `categories` | Optional shortcuts the app offers when composing posts |

## Automatic detection

If you leave `inkstead` out of the config, Sumi still tries to infer useful values during CI builds. On GitHub Actions, GitLab CI or Forgejo Actions, the build can usually detect the provider, repository, branch and instance URL from environment variables.

If repository details are not available, the app can ask for them during setup.

## The published site file

During builds, Sumi publishes a small public file at the root of your site:

```text
/sumi.json
```

It does not contain tokens or secrets, only public setup information for the app. It looks like this:

```json
{
  "branch": "main",
  "categories": ["Notes", "Photos"],
  "mediaPath": "content/media",
  "owner": "owner",
  "postsPath": "content/posts",
  "provider": "github",
  "repo": "site",
  "siteName": "My Website",
  "syndicationProviders": ["mastodon"]
}
```

The file also includes a `version` field recording the Sumi release that built the site.

Authentication happens in the app. Sumi never writes access tokens into the built site.

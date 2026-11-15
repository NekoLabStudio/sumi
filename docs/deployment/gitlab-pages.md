# GitLab Pages

If your site lives in a GitLab repository, GitLab Pages can host it. Publishing runs through GitLab CI: you push your writing, and a pipeline builds and deploys the site for you.

## Configuration

Choose GitLab Pages during `sumi init`, or add this to `sumi.json` later:

```json
{
  "deploy": {
    "provider": "gitlab-pages"
  }
}
```

## Publishing

When GitLab Pages is selected during `init`, Sumi generates `.gitlab-ci.yml` with a Pages job. Push to GitLab, or start the pipeline manually from GitLab. The pipeline is described in [GitLab CI](../ci/gitlab-ci.md).

> **Note:** GitLab Pages is published by GitLab CI, so a local `./sumi deploy` does not publish directly to GitLab Pages.

## Variables

GitLab Pages itself does not need deployment secrets. If you use syndication, add the provider variables from `.env.example` as GitLab CI/CD variables.

If you want to check content, config and any syndication variables before pushing, run `./sumi doctor` locally.

## Build output

By default, Sumi builds to `dist` and the GitLab Pages workflow publishes `dist`. If you change `build.output`, regenerate or update `.gitlab-ci.yml` so the Pages `publish` path matches.

extension SumiCLI {
static var initHelp: String {
        """
        Usage: sumi init [directory] [options]

        Options:
          --ci github-actions|gitlab-ci|forgejo-actions|none
          --deploy cloudflare-workers|github-pages|gitlab-pages|netlify|none
          --deploy-project-name name
          --syndication mastodon,bluesky,flickr|none
          --connection-provider github|gitlab|forgejo
          --connection-repository owner/repo
          --connection-branch branch
          --connection-instance-url url
        """
    }

    static var commandHelp: String {
        """
        Sumi

        Commands:
          build        Build the current site
          cache        List or clean downloaded Sumi binaries
          deploy       Deploy an already-built site
          dev          Build and serve the site locally
          doctor       Check site setup
          init         Create a new site
          migrate      Apply site migrations
          mcp          Run a server that answers AI coding agents from the Sumi docs
          new post     Create a new article or note
          publish      Build, deploy, syndicate, and redeploy if needed
          requirements Print required environment variables
          syndicate    Publish posts to configured syndication providers
          theme        Check, format, eject, or serve theme tooling
          update       Download the latest Sumi and migrate the site (--check, --dry-run, --to version)
          version      Print the Sumi site format version
        """
    }
}

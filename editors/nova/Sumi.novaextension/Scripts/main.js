let client = null;

function notify(title, body) {
  const request = new NotificationRequest(`sumi-${Date.now()}`);
  request.title = title;
  if (body) request.body = body;
  nova.notifications.add(request).catch(error => console.error(error));
}

exports.activate = function() {
  console.log("Activating Sumi extension.");

  nova.commands.register("sumi.restartLanguageServer", function() {
    stopLanguageServer();
    startLanguageServer();
  });

  nova.commands.register("sumi.checkTheme", function() {
    runSumi("Sumi check", ["theme", "check"], "No template issues found.");
  });

  // Site commands run the site's launcher and report the result.
  ["dev", "build", "deploy", "migrate", "doctor"].forEach(function(name) {
    nova.commands.register(`sumi.${name}`, function() {
      runSumi(`Sumi ${name}`, [name], "Done.");
    });
  });

  startLanguageServer();
};

exports.deactivate = function() {
  stopLanguageServer();
};

function startLanguageServer() {
  try {
    const invocation = sumiInvocation(["theme", "language-server"]);
    client = new LanguageClient(
      "sumi",
      "Sumi",
      {
        path: invocation.path,
        args: invocation.args,
        type: "stdio"
      },
      {
        syntaxes: ["sumi"]
      }
    );
    console.log(`Starting Sumi language server: ${invocation.path} ${invocation.args.join(" ")}`);
    client.start();
  } catch (error) {
    console.error(`Failed to start Sumi language server: ${error && error.message ? error.message : error}`);
    client = null;
  }
}

function stopLanguageServer() {
  if (client) {
    client.stop();
    client = null;
  }
}

// How to run `sumi <subArgs>`: the configured sumi.toolPath, else the site's
// ./sumi launcher (which pins the site's Sumi version), else sumi on PATH.
function sumiInvocation(subArgs) {
  const configured = nova.config.get("sumi.toolPath");
  if (configured && configured.trim().length > 0) {
    return { path: configured.trim(), args: subArgs };
  }
  const launcher = nova.workspace.path ? nova.path.join(nova.workspace.path, "sumi") : null;
  if (launcher && nova.fs.access(launcher, nova.fs.X_OK)) {
    return { path: launcher, args: subArgs };
  }
  return { path: "/usr/bin/env", args: ["sumi"].concat(subArgs) };
}

function runSumi(title, subArgs, emptyMessage) {
  const invocation = sumiInvocation(subArgs);
  const workspace = nova.workspace.path || undefined;
  console.log(`sumi ${subArgs.join(" ")}`);
  const process = new Process(invocation.path, { args: invocation.args, cwd: workspace });
  let output = "";
  process.onStdout(function(line) { output += line; console.log(line); });
  process.onStderr(function(line) { output += line; console.error(line); });
  process.onDidExit(function(status) {
    const ok = status === 0;
    notify(ok ? `${title} passed` : `${title} failed`,
           output.trim() || (ok ? emptyMessage : `Exited with status ${status}. See the Extension Console for details.`));
  });
  try {
    process.start();
  } catch (error) {
    notify(`${title} failed`, error && error.message ? error.message : String(error));
  }
}

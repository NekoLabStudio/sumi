const fs = require("fs");
const path = require("path");
const childProcess = require("child_process");
const vscode = require("vscode");
const { LanguageClient } = require("vscode-languageclient/node");

let client;
let outputChannel;

function activate(context) {
  outputChannel = vscode.window.createOutputChannel("Sumi");
  context.subscriptions.push(outputChannel);

  startLanguageServer(context);

  context.subscriptions.push(vscode.commands.registerCommand("sumi.restartLanguageServer", async () => {
    if (client) {
      await client.stop();
      client = undefined;
    }
    startLanguageServer(context);
  }));

  context.subscriptions.push(vscode.commands.registerCommand("sumi.checkTheme", () => {
    const workspace = workspaceFolder();
    const command = resolveToolCommand(workspace);
    outputChannel.show(true);
    outputChannel.appendLine(`Running ${command.display} theme check`);
    childProcess.execFile(command.path, ["theme", "check"], { cwd: workspace }, (error, stdout, stderr) => {
      if (stdout) outputChannel.append(stdout);
      if (stderr) outputChannel.append(stderr);
      if (error) {
        showCommandError(command, "Sumi check failed.");
      } else {
        vscode.window.showInformationMessage("Sumi check passed.");
      }
    });
  }));

  // Site commands run in an integrated terminal, so their output and any
  // prompts stay visible.
  const siteCommands = {
    "sumi.dev": ["dev"],
    "sumi.build": ["build"],
    "sumi.deploy": ["deploy"],
    "sumi.migrate": ["migrate"],
    "sumi.doctor": ["doctor"]
  };
  for (const id of Object.keys(siteCommands)) {
    context.subscriptions.push(
      vscode.commands.registerCommand(id, () => runSumi(siteCommands[id])));
  }
}

async function deactivate() {
  if (client) {
    await client.stop();
    client = undefined;
  }
}

function startLanguageServer(context) {
  const workspace = workspaceFolder();
  const command = resolveToolCommand(workspace);
  client = new LanguageClient(
    "sumi",
    "Sumi",
    {
      command: command.path,
      args: ["theme", "language-server"],
      options: { cwd: workspace }
    },
    {
      documentSelector: [{ scheme: "file", language: "sumi" }],
      outputChannel
    }
  );
  context.subscriptions.push(client.start());
}

// The configured sumi.toolPath, else the site's ./sumi launcher (which pins the
// site's Sumi version), else sumi on PATH.
function resolveToolCommand(workspace) {
  const configured = vscode.workspace.getConfiguration("sumi").get("toolPath");
  if (configured && configured.trim()) {
    return { path: configured.trim(), display: configured.trim() };
  }
  if (workspace) {
    const launcher = path.join(workspace, "sumi");
    if (fs.existsSync(launcher)) {
      return { path: launcher, display: "./sumi" };
    }
  }
  return { path: "sumi", display: "sumi" };
}

let sumiTerminal;
function runSumi(args) {
  const workspace = workspaceFolder();
  const command = resolveToolCommand(workspace);
  if (!sumiTerminal || sumiTerminal.exitStatus !== undefined) {
    sumiTerminal = vscode.window.createTerminal({ name: "Sumi", cwd: workspace });
  }
  sumiTerminal.show();
  sumiTerminal.sendText(`${command.display} ${args.join(" ")}`);
}

function workspaceFolder() {
  const editor = vscode.window.activeTextEditor;
  if (editor) {
    const folder = vscode.workspace.getWorkspaceFolder(editor.document.uri);
    if (folder) return folder.uri.fsPath;
  }
  const folder = vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders[0];
  return folder ? folder.uri.fsPath : process.cwd();
}

function showCommandError(command, fallback) {
  if (command.display === "sumi") {
    vscode.window.showErrorMessage(`${fallback} Install Sumi, or set sumi.toolPath to a sumi executable.`);
  } else {
    vscode.window.showErrorMessage(`${fallback} See the Sumi output for details.`);
  }
}

module.exports = { activate, deactivate };

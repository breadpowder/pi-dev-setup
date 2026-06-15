import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFileSync } from "node:child_process";

const YEET_PROMPT = `Commit and push the current repository changes.

Steps:
1. Identify the files that were modified during this coding session. Add only those relevant files with \`git add <file>...\`; do not use \`git add -A\`.
2. Inspect the staged changes and write a concise commit message that accurately summarizes them.
3. Commit the changes with that message.
4. Push the commit to the current branch's remote.
   - If the current branch does not have an upstream remote branch, create one by pushing with upstream tracking.
   - If this repository has no git remotes configured, do not push.
5. After pushing, output the remote URL for what was pushed if the repository has a remote.
   - If the current branch is \`main\`, output the normal remote repository URL.
   - If the current branch is not \`main\`, output a URL to create a pull request from the pushed branch into \`main\`.
   - Convert SSH git remotes like \`git@github.com:owner/repo.git\` to HTTPS URLs when printing.

Keep the commit message concise.`;

function sshToHttps(url: string): string {
  const match = url.match(/^git@github\.com:([^/]+)\/(.+?)\.git$/);
  if (match) {
    return `https://github.com/${match[1]}/${match[2]}`;
  }
  return url.replace(/\.git$/, "");
}

function runGit(cwd: string, args: string[]): string {
  return execFileSync("git", ["-c", "color.ui=false", ...args], { cwd, encoding: "utf8", stdio: ["pipe", "pipe", "ignore"] }).trim();
}

function headlessYeet(cwd: string): string {
  const files = runGit(cwd, ["diff", "--name-only", "HEAD"])
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);

  if (files.length === 0) {
    return "No changes to commit.";
  }

  runGit(cwd, ["add", "--", ...files]);

  const diffStat = runGit(cwd, ["diff", "--cached", "--stat"]);
  const summary = files.length === 1 ? `update ${files[0]}` : `update ${files.length} files`;
  const message = diffStat ? `${summary}\n\n${diffStat}` : summary;

  runGit(cwd, ["commit", "-m", message]);

  const branch = runGit(cwd, ["branch", "--show-current"]);
  const remotes = runGit(cwd, ["remote"]);

  if (!remotes) {
    return `Committed ${files.length} file(s) to ${branch}. No remote configured; skipped push.`;
  }

  const hasUpstream = runGit(cwd, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"]).length > 0;
  if (hasUpstream) {
    runGit(cwd, ["push"]);
  } else {
    runGit(cwd, ["push", "-u", "origin", branch]);
  }

  const remoteUrl = runGit(cwd, ["remote", "get-url", "origin"]);
  const httpsUrl = sshToHttps(remoteUrl);

  if (branch === "main") {
    return `Committed and pushed ${files.length} file(s) to ${branch}.\n${httpsUrl}`;
  }
  return `Committed and pushed ${files.length} file(s) to ${branch}.\n${httpsUrl}/compare/main...${branch}`;
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("yeet", {
    description: "Add, commit, and push the current repo changes",
    handler: async (args, ctx) => {
      const prompt = args?.trim()
        ? `${YEET_PROMPT}\n\nAdditional instructions from the user:\n${args.trim()}`
        : YEET_PROMPT;

      if (ctx.mode !== "tui") {
        const cwd = ctx.projectPath || process.cwd();
        const output = headlessYeet(cwd);
        pi.sendMessage({ customType: "yeet-output", content: output, display: true });
        return;
      }

      if (ctx.isIdle()) {
        pi.sendUserMessage(prompt);
      } else {
        pi.sendUserMessage(prompt, { deliverAs: "followUp" });
        ctx.ui.notify("Queued /yeet as a follow-up", "info");
      }
    },
  });
}

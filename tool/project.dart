import "dart:io";
import "package:build_tools/build_shell.dart";
import "package:build_tools/build_tools.dart";
import "package:build_tools/build_utils.dart";
import "package:file_utils/file_utils.dart";

const String PUBSPEC_YAML = "pubspec.yaml";

void main(List<String> args) {
  // http://dartbug.com/20119 (before change directory)
  var script = Platform.script;

  // Change directory to root
  FileUtils.chdir("..");

  target("default", ["git:status"], null, description: "git status");

  target("git:status", [], (Target t, Map args) {
    return exec("git", ["status", "--short"]);
  }, description: "git status --short");

  target("git:add", [], (Target t, Map args) {
    return exec("git", ["add", "--all"]);
  }, description: "git add --all");

  target("git:commit", ["update_pubspec", "git:add"], (Target t, Map args) {
    var message = args["m"];
    if (message == null || message.isEmpty) {
      print("Please, specify the `commit` message with --m option");
      return -1;
    }

    return exec("git", ["commit", "-m", message]);
  }, description: "git commit -m \"message\"");

  target("git:push", [], (Target t, Map args) {
    return exec("git", ["push", "origin", "master"]);
  }, description: "git push origin master");

  target("prj:version", [], (Target t, Map args) {
    print("Version: ${getVersion()}");
  }, description: "display version", reusable: true);

  target("update_pubspec", [], (Target t, Map args) {
    if (needChangeVersion()) {
      updatetVersion(incrementVersion(getVersion()));
      print("The version number changed: ${getVersion()}");
    }
  }, reusable: true);

  new BuildShell().run(args).then((exitCode) => exit(exitCode));
}

String getVersion() {
  var file = new File(PUBSPEC_YAML);
  var lines = file.readAsLinesSync();
  var version = "0.0.1";
  for (var line in lines) {
    if (line.startsWith("version")) {
      var index = line.indexOf(":");
      if (index != -1 && line.length > index + 1) {
        version = line.substring(index + 1).trim();
      }
    }
  }

  return version;
}

String incrementVersion(String version) {
  var parts = version.split(".");
  if (parts.length < 3) {
    return version;
  }

  var patch = int.parse(parts[2], onError: (x) => null);
  if (patch == null) {
    return version;
  }

  parts[2] = ++patch;
  parts.length = 3;
  return parts.join(".");
}

bool needChangeVersion() {
  var result = Process.runSync("git", ["status", "--porcelain"]);
  var hasChanges = false;
  String output = result.stdout.toString();
  var lines = output.split("\n");
  for (var line in lines) {
    if (line.length > 2) {
      var status = line.substring(0, 2);
      switch (status) {
        case " M":
        case "MM":
        case "AM":
        case "RM":
        case "CM":
        case " D":
        case "MD":
        case "AD":
        case "RD":
        case "CD":
          hasChanges = true;
          break;
      }
    }
  }

  return hasChanges;
}

void updatetVersion(String version) {
  var file = new File(PUBSPEC_YAML);
  var found = false;
  var lines = file.readAsLinesSync();
  var sb = new StringBuffer();
  for (var line in lines) {
    if (line.startsWith("version")) {
      found = true;
      break;
    }
  }

  if (!found) {
    var pos = lines.length == 0 ? 0 : 1;
    lines.insert(pos, "version: $version");
  }

  for (var line in lines) {
    if (line.startsWith("version")) {
      sb.writeln("version: $version");
    } else {
      sb.writeln(line);
    }
  }

  var string = sb.toString();
  file.writeAsStringSync(string);
}

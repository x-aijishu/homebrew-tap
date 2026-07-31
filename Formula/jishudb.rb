class Jishudb < Formula
  desc "JishuDB local bilingual knowledge database with hybrid retrieval and reranking"
  homepage "https://github.com/x-aijishu/jishudb"
  license "Apache-2.0"
  version "0.4.1"
  # Source revision: 41a36e3bbada8faf3f0f5e672ebc67a17af0ddb2

  url "https://github.com/x-aijishu/jishudb-releases/releases/download/v0.4.1/jishudb-0.4.1-darwin-arm64-runtime.tar.gz"
  sha256 "17674533d430e94345d7082612ce52fadbfe4c8a65e4b6e53afcaec1f693b400"

  depends_on :macos
  depends_on arch: :arm64
  depends_on "node@22"
  depends_on "python@3.12"
  depends_on "tesseract-lang"

  def install
    # Homebrew rewrites Mach-O linkage before post_install. Keep the prebuilt
    # Python wheels archived until then so their vendor dylibs retain the
    # install names already validated by the native bundle smoke.
    python_runtime_archive = buildpath/"python-site-packages.tar.gz"
    system "tar", "-C", buildpath, "-czf", python_runtime_archive, "python-site-packages"

    libexec.install "jishudb", "jishudb-device-auth"
    pkgshare.install \
      "RELEASE-MANIFEST.json", \
      "demo-data", \
      "node_modules", \
      "package-lock.json", \
      "package.json", \
      python_runtime_archive, \
      "scripts", \
      "vendor", \
      "web"
    prefix.install "LICENSE", "NOTICE"

    node_bin = Formula["node@22"].opt_bin
    python_bin = Formula["python@3.12"].opt_libexec/"bin"
    { "jishudb" => "jishudb" }.each do |command, cli_name|
      (bin/command).write <<~SH
        #!/bin/bash
        set -euo pipefail

        : "${HOME:?HOME must be set}"
        app_support="${JISHUDB_HOME:-${HOME}/Library/Application Support/JishuDB}"

        export JISHUDB_CLI_NAME="#{cli_name}"
        export JISHUDB_HOMEBREW_FORMULA="jishudb"
        export PATH="#{node_bin}:#{python_bin}:${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"
        export JISHUDB_DATA="${JISHUDB_DATA:-${app_support}/data}"
        export JISHUDB_MODELS="${JISHUDB_MODELS:-${app_support}/models}"
        export JISHUDB_WEB_DIR="${JISHUDB_WEB_DIR:-#{opt_pkgshare}/web}"
        export JISHUDB_SCRIPTS_DIR="${JISHUDB_SCRIPTS_DIR:-#{opt_pkgshare}/scripts}"
        export JISHUDB_DEMO_DATA="${JISHUDB_DEMO_DATA:-#{opt_pkgshare}/demo-data}"
        export JISHUDB_NODE_MODULES="${JISHUDB_NODE_MODULES:-#{opt_pkgshare}/node_modules}"
        export PYTHONPATH="#{opt_pkgshare}/python-site-packages${PYTHONPATH:+:${PYTHONPATH}}"
        export JISHUDB_HOST="${JISHUDB_HOST:-127.0.0.1}"
        export JISHUDB_PORT="${JISHUDB_PORT:-8088}"
        export JISHUDB_DEVICE_AUTH_HELPER="${JISHUDB_DEVICE_AUTH_HELPER:-#{opt_libexec}/jishudb-device-auth}"
        export JISHUDB_DEVICE_AUTH_RECOVERY="${JISHUDB_DEVICE_AUTH_RECOVERY:-1}"
        export JISHUDB_DEFAULT_ALLOW_REMOTE_MODELS="${JISHUDB_DEFAULT_ALLOW_REMOTE_MODELS:-0}"
        export JISHUDB_UPGRADE_ENABLED="${JISHUDB_UPGRADE_ENABLED:-0}"

        exec "#{opt_libexec}/jishudb" "$@"
      SH
      (bin/command).chmod 0755
    end
  end

  def post_install
    python_runtime = pkgshare/"python-site-packages"
    FileUtils.rm_rf(python_runtime)
    system "tar", "-xzf", pkgshare/"python-site-packages.tar.gz", "-C", pkgshare

    app_support = Pathname.new(Dir.home)/"Library/Application Support/JishuDB"
    logs = Pathname.new(Dir.home)/"Library/Logs/JishuDB"
    [app_support/"data", app_support/"models", app_support/"backups", logs].each do |path|
      path.mkpath
      path.chmod 0700
    end
  end

  service do
    run [opt_bin/"jishudb", "serve"]
    keep_alive crashed: true
    restart_delay 5
    working_dir opt_pkgshare
    log_path Pathname.new(Dir.home)/"Library/Logs/JishuDB/jishudb.log"
    error_log_path Pathname.new(Dir.home)/"Library/Logs/JishuDB/jishudb-error.log"
    environment_variables HOME: Dir.home, PATH: std_service_path_env
  end

  test do
    assert_match "jishudb #{version}", shell_output("#{bin}/jishudb --version")
    assert_path_exists pkgshare/"RELEASE-MANIFEST.json"
    assert_path_exists pkgshare/"scripts/local-onnx-worker.mjs"
    assert_path_exists pkgshare/"python-site-packages"
    assert_predicate libexec/"jishudb-device-auth", :executable?
  end
end

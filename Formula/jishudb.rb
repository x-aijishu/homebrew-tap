class Jishudb < Formula
  desc "JishuDB local bilingual knowledge database with hybrid retrieval and reranking"
  homepage "https://github.com/x-aijishu/jishu-kb"
  license "Apache-2.0"
  version "0.3.2"
  # Source revision: d62a4af3f9c2ecc5a27c65542a31a7625ed53d49

  url "https://github.com/x-aijishu/jishu-kb-releases/releases/download/v0.3.2/jishu-kb-0.3.2-darwin-arm64-runtime.tar.gz"
  sha256 "aa2a2012acd8ab10eaec5fd727f5b5d17f93815fef41300158af4589860044cb"

  depends_on :macos
  depends_on arch: :arm64
  depends_on "node@22"
  depends_on "python@3.12"
  depends_on "tesseract-lang"

  conflicts_with "jishu-kb", because: "both Formulae manage the same service, port, and data directory"

  def install
    # Homebrew rewrites Mach-O linkage before post_install. Keep the prebuilt
    # Python wheels archived until then so their vendor dylibs retain the
    # install names already validated by the native bundle smoke.
    python_runtime_archive = buildpath/"python-site-packages.tar.gz"
    system "tar", "-C", buildpath, "-czf", python_runtime_archive, "python-site-packages"

    libexec.install "jishu-kb", "jishu-kb-device-auth"
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
    { "jishudb" => "jishudb", "jishu-kb" => "jishu-kb" }.each do |command, cli_name|
      (bin/command).write <<~SH
        #!/bin/bash
        set -euo pipefail

        : "${HOME:?HOME must be set}"
        app_support="${JISHUDB_HOME:-${JISHU_KB_HOME:-${HOME}/Library/Application Support/JishuShell-KB}}"

        export JISHUDB_CLI_NAME="#{cli_name}"
        export JISHUDB_HOMEBREW_FORMULA="jishudb"
        export PATH="#{node_bin}:#{python_bin}:${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"
        export JISHU_KB_DATA="${JISHU_KB_DATA:-${app_support}/data}"
        export JISHU_KB_MODELS="${JISHU_KB_MODELS:-${app_support}/models}"
        export JISHU_KB_WEB_DIR="${JISHU_KB_WEB_DIR:-#{opt_pkgshare}/web}"
        export JISHU_KB_SCRIPTS_DIR="${JISHU_KB_SCRIPTS_DIR:-#{opt_pkgshare}/scripts}"
        export JISHU_KB_DEMO_DATA="${JISHU_KB_DEMO_DATA:-#{opt_pkgshare}/demo-data}"
        export JISHU_KB_NODE_MODULES="${JISHU_KB_NODE_MODULES:-#{opt_pkgshare}/node_modules}"
        export PYTHONPATH="#{opt_pkgshare}/python-site-packages${PYTHONPATH:+:${PYTHONPATH}}"
        export JISHU_KB_HOST="${JISHU_KB_HOST:-127.0.0.1}"
        export JISHU_KB_PORT="${JISHU_KB_PORT:-8088}"
        export JISHU_KB_DEVICE_AUTH_HELPER="${JISHU_KB_DEVICE_AUTH_HELPER:-#{opt_libexec}/jishu-kb-device-auth}"
        export JISHU_KB_DEVICE_AUTH_RECOVERY="${JISHU_KB_DEVICE_AUTH_RECOVERY:-1}"
        export JISHU_KB_DEFAULT_ALLOW_REMOTE_MODELS="${JISHU_KB_DEFAULT_ALLOW_REMOTE_MODELS:-0}"
        export JISHU_KB_UPGRADE_ENABLED="${JISHU_KB_UPGRADE_ENABLED:-0}"

        exec "#{opt_libexec}/jishu-kb" "$@"
      SH
      (bin/command).chmod 0755
    end
  end

  def post_install
    python_runtime = pkgshare/"python-site-packages"
    FileUtils.rm_rf(python_runtime)
    system "tar", "-xzf", pkgshare/"python-site-packages.tar.gz", "-C", pkgshare

    app_support = Pathname.new(Dir.home)/"Library/Application Support/JishuShell-KB"
    logs = Pathname.new(Dir.home)/"Library/Logs/JishuShell-KB"
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
    log_path Pathname.new(Dir.home)/"Library/Logs/JishuShell-KB/jishu-kb.log"
    error_log_path Pathname.new(Dir.home)/"Library/Logs/JishuShell-KB/jishu-kb-error.log"
    environment_variables HOME: Dir.home, PATH: std_service_path_env
  end

  test do
    assert_match "jishudb #{version}", shell_output("#{bin}/jishudb --version")
    assert_match "jishu-kb #{version}", shell_output("#{bin}/jishu-kb --version")
    assert_path_exists pkgshare/"RELEASE-MANIFEST.json"
    assert_path_exists pkgshare/"scripts/local-onnx-worker.mjs"
    assert_path_exists pkgshare/"python-site-packages"
    assert_predicate libexec/"jishu-kb-device-auth", :executable?
  end
end

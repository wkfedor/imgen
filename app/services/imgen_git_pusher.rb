# frozen_string_literal: true

require "open3"

class ImgenGitPusher
  class Error < StandardError
    attr_reader :log

    def initialize(message, log: nil)
      super(message)
      @log = log
    end
  end

  DEFAULT_REMOTE = "https://github.com/wkfedor/imgen.git"
  LOG_PREFIX = "[imgen-git]"

  def self.call(root: nil, remote_url: nil, commit_message: nil)
    new(root: root, remote_url: remote_url, commit_message: commit_message).call
  end

  def initialize(root: nil, remote_url: nil, commit_message: nil)
    @root = Pathname(root || Rails.root).expand_path
    @remote_url = remote_url.presence || ENV.fetch("IMGEN_GIT_REMOTE", DEFAULT_REMOTE)
    @commit_message = commit_message
  end

  def call
    raise Error, "Нет каталога #{@root}" unless @root.directory?

    log = []
    log_line(log, "start root=#{@root}")

    ensure_git_repo!(log)
    ensure_remote!(log)
    branch = ensure_branch!(log)

    ok, = git_run(log, "git", "add", "-A")
    raise_error(log, "git add не удался") unless ok

    skip = nothing_to_commit_reason
    if skip
      log_line(log, "nothing to commit")
      return { ok: true, committed: false, pushed: false, message: skip, log: log.join("\n") }
    end

    message = @commit_message.presence || "Imgen: update #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
    ok, = git_run(log, "git", "commit", "-m", message)
    raise_error(log, "git commit не удался", append_git_detail: true) unless ok

    pushed = push_branch(log, branch)

    {
      ok: pushed,
      committed: true,
      pushed: pushed,
      branch: branch,
      remote: @remote_url,
      message: pushed ? "Закоммичено и отправлено в origin/#{branch}" : "Коммит создан, push не удался (см. лог)",
      log: log.join("\n")
    }
  end

  private

  def ensure_git_repo!(log)
    return if (@root / ".git").directory?

    raise_error(log, "В #{@root} нет .git. Склонируйте репозиторий: git clone #{@remote_url} #{@root.basename}")
  end

  def ensure_remote!(log)
    remotes, = capture("git", "remote")
    if remotes.lines.map(&:strip).include?("origin")
      current, = capture("git", "remote", "get-url", "origin")
      git_run(log, "git", "remote", "set-url", "origin", @remote_url) if current.strip != @remote_url
    else
      git_run(log, "git", "remote", "add", "origin", @remote_url)
    end
  end

  def ensure_branch!(log)
    branch, = capture("git", "branch", "--show-current")
    branch = branch.strip
    return branch if branch.present?

    branch = ENV.fetch("IMGEN_GIT_BRANCH", "main")
    ok, = git_run(log, "git", "checkout", "-B", branch)
    raise_error(log, "Не удалось выбрать ветку #{branch}") unless ok
    branch
  end

  def nothing_to_commit_reason
    staged, = capture("git", "diff", "--cached", "--name-only")
    return nil if staged.strip.present?

    porcelain, = capture("git", "status", "--porcelain")
    porcelain.strip.empty? ? "Нечего коммитить — рабочая копия чистая" : "Нечего коммитить — после git add нет файлов в индексе"
  end

  def push_branch(log, branch)
    ok, = git_run(log, "git", "push", "-u", "origin", branch)
    return true if ok

    log_line(log, "push отклонён — fetch + pull --no-rebase + повторный push")
    git_run(log, "git", "fetch", "origin", branch)
    git_run(log, "git", "pull", "--no-rebase", "origin", branch)
    ok, = git_run(log, "git", "push", "-u", "origin", branch)
    ok
  end

  def raise_error(log, message, append_git_detail: false)
    detail = append_git_detail ? git_output_tail(log) : nil
    full_message = detail.present? ? "#{message}: #{detail}" : message
    raise Error.new(full_message, log: log.join("\n"))
  end

  def git_output_tail(log)
    log.reject { |line| line.start_with?(LOG_PREFIX) || line.start_with?("$ git") }
       .map(&:strip)
       .reject(&:empty?)
       .last(8)
       .join(" | ")
  end

  def git_run(log, *cmd)
    log_line(log, "$ #{cmd.join(' ')}")
    out, err, status = Open3.capture3(*cmd, chdir: @root.to_s)
    log << out if out.present?
    log << err if err.present?
    log_line(log, "exit #{status.exitstatus}") unless status.success?
    [status.success?, status.exitstatus]
  end

  def capture(*cmd)
    Open3.capture2e(*cmd, chdir: @root.to_s)
  end

  def log_line(log, message)
    line = "#{LOG_PREFIX} #{message}"
    Rails.logger.info(line)
    log << line
  end
end

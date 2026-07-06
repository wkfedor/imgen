# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "open3"
require "securerandom"
require "shellwords"
require "uri"

class ComfyClient
  DEFAULT_NEGATIVE = "text, watermark, logo, blurry, low quality, distorted, bad anatomy, extra fingers"

  def initialize(
    direct_url: ENV.fetch("COMFYUI_URL", "http://192.168.0.106:8188"),
    remote_url: ENV.fetch("COMFYUI_REMOTE_URL", "http://127.0.0.1:8188"),
    ssh_host: ENV.fetch("IMGEN_SSH_HOST", "feda@192.168.0.106"),
    ssh_key: ENV.fetch("IMGEN_SSH_KEY", "/home/feda/.ssh/cursor_remote_key"),
    output_dir: Rails.root.join("storage/generated")
  )
    @direct_url = direct_url.sub(%r{/+$}, "")
    @remote_url = remote_url.sub(%r{/+$}, "")
    @ssh_host = ssh_host
    @ssh_key = ssh_key
    @output_dir = Pathname.new(output_dir)
    FileUtils.mkdir_p(@output_dir)
  end

  def models
    models_from_object_info(direct_object_info) ||
      models_from_object_info(remote_object_info) ||
      remote_checkpoint_files
  end

  def generate(prompt:, model:, result_id:, steps: 24, width: 1024, height: 1024)
    seed = rand(1_000_000_000)
    workflow = workflow_for(
      model: model,
      prompt: prompt,
      seed: seed,
      steps: steps,
      width: width,
      height: height,
      prefix: "imgen_#{result_id}_#{safe_name(model)}"
    )
    started_at = Time.current
    generated = direct_available? ? generate_direct(workflow) : generate_via_ssh(workflow)
    generated.merge(seed: seed, duration_sec: (Time.current - started_at).round(1))
  end

  def delete_remote_image(filename:, subfolder: nil, type: nil)
    filename = File.basename(filename.to_s)
    raise "remote filename blank" if filename.blank?

    subfolder = subfolder.to_s
    type = type.to_s.presence || "output"
    raise "remote type #{type.inspect} is not allowed" unless %w[input output temp].include?(type)

    relative = [type, subfolder, filename].reject(&:blank?).join("/")
    ssh_capture("ruby -e #{Shellwords.escape(remote_delete_script)} -- #{Shellwords.escape(relative)}")
    true
  end

  private

  def direct_available?
    !!direct_object_info
  end

  def direct_object_info
    get_json("#{@direct_url}/object_info", timeout: 8)
  rescue StandardError
    nil
  end

  def remote_object_info
    output = ssh_capture("curl -sS --connect-timeout 5 --max-time 20 #{Shellwords.escape("#{@remote_url}/object_info")}")
    JSON.parse(output)
  rescue StandardError
    nil
  end

  def models_from_object_info(info)
    raw = info&.dig("CheckpointLoaderSimple", "input", "required", "ckpt_name", 0)
    models = Array(raw).map(&:to_s).select { |name| name.end_with?(".safetensors", ".ckpt") }.uniq.sort
    models.presence
  end

  def remote_checkpoint_files
    command = "find ~/ComfyUI/models/checkpoints -maxdepth 1 -type f \( -name '*.safetensors' -o -name '*.ckpt' \) -printf '%f\n' | sort"
    ssh_capture(command).lines.map(&:strip).reject(&:blank?)
  end

  def generate_direct(workflow)
    response = post_json("#{@direct_url}/prompt", prompt: workflow, client_id: SecureRandom.uuid)
    prompt_id = response.fetch("prompt_id")
    image = wait_for_image(base_url: @direct_url, prompt_id: prompt_id)
    save_direct_image(image: image, prompt_id: prompt_id)
  end

  def generate_via_ssh(workflow)
    payload = JSON.generate(prompt: workflow, client_id: SecureRandom.uuid)
    output, error, status = Open3.capture3(
      *ssh_command("COMFYUI_REMOTE_URL=#{Shellwords.escape(@remote_url)} ruby -e #{Shellwords.escape(remote_generation_script)}"),
      stdin_data: payload
    )
    raise "ssh generation failed: #{error.strip}" unless status.success?

    meta_raw, image_body = output.split("\n---IMGEN_IMAGE---\n", 2)
    raise "ssh generation returned no image body" if image_body.blank?

    meta = JSON.parse(meta_raw, symbolize_names: true)
    image = meta.fetch(:image)
    filename = local_filename(image[:filename], meta.fetch(:prompt_id))
    path = @output_dir.join(filename)
    File.binwrite(path, image_body)
    {
      prompt_id: meta.fetch(:prompt_id),
      filename: filename,
      path: path.to_s,
      bytes: File.size(path),
      remote_filename: image[:filename],
      remote_subfolder: image[:subfolder],
      remote_type: image[:type]
    }
  end

  def remote_generation_script
    <<~'RUBY'
      require "json"
      require "net/http"
      require "uri"

      server = ENV.fetch("COMFYUI_REMOTE_URL")
      payload = JSON.parse(STDIN.read)

      def post_json(url, payload)
        uri = URI(url)
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(payload)
        Net::HTTP.start(uri.host, uri.port, read_timeout: 30, open_timeout: 5) { |http| http.request(request) }
      end

      response = post_json("#{server}/prompt", payload)
      raise "prompt failed #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)
      prompt_id = JSON.parse(response.body).fetch("prompt_id")
      deadline = Time.now + Integer(ENV.fetch("IMGEN_TIMEOUT", "1200"))
      history = nil

      until Time.now > deadline
        result = Net::HTTP.get_response(URI("#{server}/history/#{prompt_id}"))
        raise "history failed #{result.code}: #{result.body}" unless result.is_a?(Net::HTTPSuccess)
        history = JSON.parse(result.body)[prompt_id]
        outputs = history && history.fetch("outputs", {})
        break if outputs.values.any? { |node| node["images"].to_a.any? }
        sleep 1
      end

      outputs = history && history.fetch("outputs", {})
      node = outputs&.values&.find { |value| value["images"].to_a.any? }
      image = node && node.fetch("images").first
      raise "generation timeout or no image for prompt_id=#{prompt_id}" unless image

      query = URI.encode_www_form(filename: image.fetch("filename"), subfolder: image.fetch("subfolder", ""), type: image.fetch("type", "output"))
      image_response = Net::HTTP.get_response(URI("#{server}/view?#{query}"))
      raise "view failed #{image_response.code}: #{image_response.body[0, 200]}" unless image_response.is_a?(Net::HTTPSuccess)

      STDOUT.binmode
      STDOUT.write(JSON.generate(prompt_id: prompt_id, image: image, bytes: image_response.body.bytesize))
      STDOUT.write("\n---IMGEN_IMAGE---\n")
      STDOUT.write(image_response.body)
    RUBY
  end

  def remote_delete_script
    <<~'RUBY'
      require "pathname"

      relative = ARGV.fetch(0)
      root = Pathname(ENV.fetch("COMFYUI_ROOT", File.expand_path("~/ComfyUI")))
      allowed_roots = {
        "input" => root.join("input"),
        "output" => root.join("output"),
        "temp" => root.join("temp")
      }
      type = relative.split("/", 2).first
      base = allowed_roots.fetch(type)
      target = root.join(relative).cleanpath

      unless target.to_s.start_with?(base.cleanpath.to_s + "/")
        raise "refuse to delete outside #{base}: #{target}"
      end

      if target.file?
        target.delete
        puts "deleted #{target}"
      else
        puts "not found #{target}"
      end
    RUBY
  end

  def wait_for_image(base_url:, prompt_id:)
    deadline = Time.current + 20.minutes
    until Time.current > deadline
      history = get_json("#{base_url}/history/#{prompt_id}")
      outputs = history[prompt_id]&.fetch("outputs", {})
      node = outputs&.values&.find { |value| value["images"].to_a.any? }
      return node.fetch("images").first if node
      sleep 1
    end
    raise "generation timeout or no image for prompt_id=#{prompt_id}"
  end

  def save_direct_image(image:, prompt_id:)
    query = URI.encode_www_form(filename: image.fetch("filename"), subfolder: image.fetch("subfolder", ""), type: image.fetch("type", "output"))
    uri = URI("#{@direct_url}/view?#{query}")
    response = Net::HTTP.start(uri.host, uri.port, read_timeout: 60, open_timeout: 5) { |http| http.request(Net::HTTP::Get.new(uri)) }
    raise "view failed #{response.code}: #{response.body[0, 200]}" unless response.is_a?(Net::HTTPSuccess)

    filename = local_filename(image.fetch("filename"), prompt_id)
    path = @output_dir.join(filename)
    File.binwrite(path, response.body)
    {
      prompt_id: prompt_id,
      filename: filename,
      path: path.to_s,
      bytes: File.size(path),
      remote_filename: image.fetch("filename"),
      remote_subfolder: image.fetch("subfolder", ""),
      remote_type: image.fetch("type", "output")
    }
  end

  def workflow_for(model:, prompt:, seed:, steps:, width:, height:, prefix:)
    {
      "3" => { "class_type" => "KSampler", "inputs" => { "seed" => seed, "steps" => steps, "cfg" => 7.0, "sampler_name" => "euler", "scheduler" => "normal", "denoise" => 1.0, "model" => ["4", 0], "positive" => ["6", 0], "negative" => ["7", 0], "latent_image" => ["5", 0] } },
      "4" => { "class_type" => "CheckpointLoaderSimple", "inputs" => { "ckpt_name" => model } },
      "5" => { "class_type" => "EmptyLatentImage", "inputs" => { "width" => width, "height" => height, "batch_size" => 1 } },
      "6" => { "class_type" => "CLIPTextEncode", "inputs" => { "text" => prompt, "clip" => ["4", 1] } },
      "7" => { "class_type" => "CLIPTextEncode", "inputs" => { "text" => DEFAULT_NEGATIVE, "clip" => ["4", 1] } },
      "8" => { "class_type" => "VAEDecode", "inputs" => { "samples" => ["3", 0], "vae" => ["4", 2] } },
      "9" => { "class_type" => "SaveImage", "inputs" => { "filename_prefix" => prefix, "images" => ["8", 0] } }
    }
  end

  def get_json(url, timeout: 20)
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, read_timeout: timeout, open_timeout: 5) { |http| http.request(Net::HTTP::Get.new(uri)) }
    raise "GET #{url} failed #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  end

  def post_json(url, payload)
    uri = URI(url)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(payload)
    response = Net::HTTP.start(uri.host, uri.port, read_timeout: 30, open_timeout: 5) { |http| http.request(request) }
    raise "POST #{url} failed #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  end

  def ssh_capture(command)
    output, error, status = Open3.capture3(*ssh_command(command))
    raise "ssh failed: #{error.strip}" unless status.success?
    output
  end

  def ssh_command(command)
    ["ssh", "-i", @ssh_key, "-o", "IdentitiesOnly=yes", "-o", "BatchMode=yes", @ssh_host, command]
  end

  def safe_name(value)
    value.to_s.gsub(/[^a-zA-Z0-9_.-]+/, "_")[0, 80]
  end

  def local_filename(remote_filename, prompt_id)
    base = File.basename(remote_filename.to_s.presence || "image.png")
    ext = File.extname(base).presence || ".png"
    stem = File.basename(base, ext).gsub(/[^a-zA-Z0-9_.-]+/, "_")[0, 120]
    "#{stem}_#{prompt_id}#{ext}"
  end
end

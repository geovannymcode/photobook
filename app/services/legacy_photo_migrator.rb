require "digest"

# Paperclip's default :rails_root/public/system/:class/:attachment/:id_partition/:style/:filename.
# Source files and legacy columns are deliberately never deleted.
class LegacyPhotoMigrator
  def initialize(root:, mode: "dry_run", output: $stdout)
    @root = Pathname.new(root).realpath
    @mode = mode
    @output = output
    raise ArgumentError, "mode must be dry_run, import or verify" unless %w[dry_run import verify].include?(mode)
  end

  def call
    counts = Hash.new(0)
    Post.where.not(photo_file_name: [ nil, "" ]).find_each do |post|
      begin
        source = source_for(post)
        if post.photo.attached?
          if @mode == "verify"
            digest = Digest::MD5.file(source).base64digest
            raise "Source checksum differs" unless post.photo.blob.checksum == digest
            raise "Stored bytes differ" unless Digest::MD5.base64digest(post.photo.download) == digest
            [ :large, :medium, :thumb ].each { |name| post.photo.variant(name).processed }
            counts[:verified] += 1
          else
            counts[:already_attached] += 1
          end
        elsif @mode == "import"
          File.open(source, "rb") do |io|
            post.with_lock do
              unless post.photo.attached?
                post.photo = { io: io, filename: source.basename.to_s, content_type: Marcel::MimeType.for(io) }
                post.save!
                counts[:imported] += 1
              end
            end
          end
        elsif @mode == "verify"
          raise "Photo has not been imported"
        else
          counts[:available] += 1
        end
      rescue StandardError => error
        counts[:failed] += 1
        # Do not log filenames, user profile data or arbitrary exception messages.
        @output.puts "Post #{post.id}: failed (#{error.class})"
      end
    end
    @output.puts counts.sort.to_h.inspect
    raise "Legacy photo migration incomplete: #{counts[:failed]} failed" if counts[:failed].positive?
    counts
  end

  private

  def source_for(post)
    filename = post.photo_file_name
    raise "Unsafe filename" unless filename == File.basename(filename) && !filename.include?("\\")

    partition = post.id.to_s.rjust(9, "0").scan(/.{3}/).join("/")
    candidate = @root.join(partition, "original", filename).realpath
    raise "Source escapes root" unless candidate.to_s.start_with?("#{@root}/") && candidate.file?
    candidate
  end
end

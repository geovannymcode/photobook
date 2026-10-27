require "vips"

class Post < ApplicationRecord
  MAX_PHOTO_SIZE = 10.megabytes
  PHOTO_TYPES = %w[image/jpeg image/png image/webp].freeze

  belongs_to :user
  has_one_attached :photo, dependent: :purge_later do |attachment|
    attachment.variant :large, resize_to_limit: [ 600, 600 ]
    attachment.variant :medium, resize_to_limit: [ 300, 300 ]
    attachment.variant :thumb, resize_to_limit: [ 100, 100 ]
  end

  validates :title, presence: true, length: { minimum: 5 }
  validates :description, length: { maximum: 64 }
  validate :acceptable_photo

  scope :recent, -> { order(created_at: :desc, id: :desc).limit(10) }

  private

  def acceptable_photo
    unless photo.attached?
      errors.add(:photo, "is required")
      return
    end

    errors.add(:photo, "must be JPEG, PNG or WebP") unless PHOTO_TYPES.include?(photo.blob.content_type)
    errors.add(:photo, "must be at most 10 MB") if photo.blob.byte_size > MAX_PHOTO_SIZE

    # Inspect upload bytes rather than trusting the browser's MIME header.
    change = attachment_changes["photo"]
    upload = change&.attachable
    io = upload.respond_to?(:tempfile) ? upload.tempfile : upload.is_a?(Hash) ? upload[:io] : nil
    if io
      detected = Marcel::MimeType.for(io)
      io.rewind
      errors.add(:photo, "has invalid image contents") unless PHOTO_TYPES.include?(detected)
      if PHOTO_TYPES.include?(detected) && photo.blob.byte_size <= MAX_PHOTO_SIZE
        begin
          image = Vips::Image.new_from_file(io.path, access: :sequential)
          errors.add(:photo, "dimensions exceed 40 megapixels") if image.width * image.height > 40_000_000
        rescue Vips::Error
          errors.add(:photo, "cannot be decoded")
        end
      end
    elsif change
      # Public forms only accept uploaded files; signed blob IDs cannot bypass validation.
      errors.add(:photo, "must be uploaded as a file")
    end
  end
end

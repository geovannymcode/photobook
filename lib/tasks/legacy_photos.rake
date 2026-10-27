namespace :legacy_photos do
  desc "Check/import/verify Paperclip originals without deleting files (MODE=dry_run|import|verify)"
  task migrate: :environment do
    LegacyPhotoMigrator.new(
      root: ENV.fetch("LEGACY_PHOTO_ROOT", Rails.root.join("public/system/posts/photos").to_s),
      mode: ENV.fetch("MODE", "dry_run")
    ).call
  end
end

# Run with: RAILS_ENV=test bin/rails runner script/verify_migrations.rb
# Only writes to a disposable database; never uses the configured application DB.
require "tmpdir"

Dir.mktmpdir("photobook-migrations") do |directory|
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: File.join(directory, "verification.sqlite3"))
  connection = ActiveRecord::Base.connection
  context = ActiveRecord::MigrationContext.new(Rails.root.join("db/migrate").to_s)
  context.up(20160521185644)
  connection.execute("INSERT INTO users (id, email, encrypted_password, username, firstname, lastname, created_at, updated_at) VALUES (1, 'legacy@example.com', 'existing-bcrypt-hash', 'legacy', 'Legacy', 'User', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
  connection.execute("INSERT INTO posts (id, title, description, user_id, photo_file_name, photo_content_type, photo_file_size, created_at, updated_at) VALUES (1, 'Legacy photo', 'Keep this', 1, 'old.jpg', 'image/jpeg', 1234, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
  before_users = connection.select_all("SELECT * FROM users").to_a
  before_posts = connection.select_all("SELECT * FROM posts").to_a
  connection.execute("INSERT INTO posts (id, title, user_id, created_at, updated_at) VALUES (2, 'Orphan photo', 999, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
  begin
    context.up
    raise "Orphan detection failed"
  rescue StandardError => error
    raise unless error.message.include?("Orphan posts detected")
  end
  raise "Data lost on failed migration" unless connection.select_value("SELECT COUNT(*) FROM posts") == 2
  connection.execute("UPDATE posts SET user_id=1 WHERE id=2")
  context.up
  raise "Legacy user changed" unless connection.select_all("SELECT * FROM users").to_a == before_users
  raise "Legacy post changed" unless connection.select_all("SELECT * FROM posts WHERE id=1").to_a == before_posts
  raise "Active Storage missing" unless connection.table_exists?(:active_storage_blobs)
  raise "Foreign key missing" unless connection.foreign_keys(:posts).any? { |key| key.to_table == "users" }
  raise "User ID nullable" if connection.columns(:posts).find { |column| column.name == "user_id" }.null
  context.down(20160521185644)
  raise "Rollback changed data" unless connection.select_all("SELECT * FROM posts WHERE id=1").to_a == before_posts
  context.up
  puts "Verified: fresh migrations, legacy data preservation, orphan rejection, constraints, rollback and reapply."
ensure
  ActiveRecord::Base.connection_pool.disconnect!
end

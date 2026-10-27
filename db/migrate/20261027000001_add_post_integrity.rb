class AddPostIntegrity < ActiveRecord::Migration[8.1]
  def up
    orphans = select_values("SELECT posts.id FROM posts LEFT JOIN users ON users.id = posts.user_id WHERE users.id IS NULL")
    raise ActiveRecord::MigrationError, "Orphan posts detected (count=#{orphans.size}); repair ownership before migrating" if orphans.any?

    add_index :posts, :user_id unless index_exists?(:posts, :user_id)
    add_index :posts, [ :created_at, :id ]
    change_column_null :posts, :user_id, false
    add_foreign_key :posts, :users
  end

  def down
    remove_foreign_key :posts, :users
    change_column_null :posts, :user_id, true
    remove_index :posts, [ :created_at, :id ]
    remove_index :posts, :user_id
  end
end

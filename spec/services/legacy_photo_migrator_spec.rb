require "rails_helper"
require "tmpdir"

RSpec.describe LegacyPhotoMigrator do
  let!(:record) { create(:post) }

  def original_path(root, filename = "photobook.jpg")
    File.join(root, record.id.to_s.rjust(9, "0").scan(/.{3}/).join("/"), "original", filename)
  end

  it "dry runs, imports idempotently and verifies originals, checksums and variants" do
    record.photo.purge
    record.update_columns(photo_file_name: "photobook.jpg")
    Dir.mktmpdir do |root|
      path = original_path(root)
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.cp(Rails.root.join("spec/factories/photobook.jpg"), path)
      output = StringIO.new
      expect(described_class.new(root: root, output: output).call[:available]).to eq(1)
      expect(record.reload.photo).not_to be_attached
      described_class.new(root: root, mode: "import", output: output).call
      blob_id = record.reload.photo.blob.id
      described_class.new(root: root, mode: "import", output: output).call
      expect(record.reload.photo.blob.id).to eq(blob_id)
      expect(described_class.new(root: root, mode: "verify", output: output).call[:verified]).to eq(1)
      expect(File).to exist(path)
      expect(record.reload.photo_file_name).to eq("photobook.jpg")
    end
  end

  it "reports missing originals and rejects traversal and symlink escapes" do
    record.update_columns(photo_file_name: "../../secret.jpg")
    Dir.mktmpdir do |root|
      expect { described_class.new(root: root, output: StringIO.new).call }.to raise_error(/incomplete/)
      record.update_columns(photo_file_name: "missing.jpg")
      expect { described_class.new(root: root, output: StringIO.new).call }.to raise_error(/incomplete/)
      path = original_path(root)
      FileUtils.mkdir_p(File.dirname(path))
      File.symlink(Rails.root.join("spec/factories/photobook.jpg"), path)
      record.update_columns(photo_file_name: "photobook.jpg")
      expect { described_class.new(root: root, output: StringIO.new).call }.to raise_error(/incomplete/)
    end
  end
end

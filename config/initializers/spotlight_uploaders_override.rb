Spotlight::AttachmentUploader.class_eval do
  def store_dir
    "#{Spotlight::Engine.config.uploader_storage_path}/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end
end

Spotlight::FeaturedImageUploader.class_eval do
  def store_dir
    "#{Spotlight::Engine.config.uploader_storage_path}/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}" 
  end
end


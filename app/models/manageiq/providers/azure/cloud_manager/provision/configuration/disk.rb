module ManageIQ::Providers::Azure::CloudManager::Provision::Configuration::Disk
  def storage_account_resource_group
    source.description.split("\\").first
  end

  def storage_account_name
    source.description.split("\\")[1]
  end

  def gather_storage_account_properties
    sas = nil

    source.with_provider_connection do |azure|
      sas = Azure::Armrest::StorageAccountService.new(azure)
    end

    return if sas.nil?

    begin
      image = sas.list_private_images(storage_account_resource_group).find do |img|
        img.uri == source.ems_ref
      end

      return unless image

      platform   = image.operating_system
      endpoint   = image.storage_account.properties.primary_endpoints.blob
      source_uri = image.uri

      target_uri = File.join(endpoint, "manageiq", dest_name + "_" + SecureRandom.uuid + ".vhd")
    rescue Azure::Armrest::ResourceNotFoundException => err
      _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
    end

    return target_uri, source_uri, platform
  end

end
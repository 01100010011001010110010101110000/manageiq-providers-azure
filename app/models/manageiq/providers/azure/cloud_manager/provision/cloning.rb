module ManageIQ::Providers::Azure::CloudManager::Provision::Cloning
  def do_clone_task_check(clone_task_ref)
    source.with_provider_connection do |azure|
      vms      = Azure::Armrest::VirtualMachineService.new(azure)
      instance = vms.get(clone_task_ref[:vm_name], clone_task_ref[:vm_resource_group])
      status   = instance.properties.provisioning_state
      return true if status == "Succeeded"
      return false, status
    end
  end

  def find_destination_in_vmdb(vm_uid_hash)
    ems_ref = vm_uid_hash.values.join("\\")
    ManageIQ::Providers::Azure::CloudManager::Vm.find_by("lower(ems_ref) = ?", ems_ref.downcase)
  end

  def custom_data
    userdata_payload.encode('UTF-8').delete("\n")
  end

  def prepare_for_clone_task
    nic_id = associated_nic || create_nic

    # TODO: Ideally this would be a check against source.storage or source.disks
    if source.ems_ref =~ /.+:.+:.+:.+/
      urn_keys = %w(publisher offer sku version)
      image_reference = Hash[urn_keys.zip(source.ems_ref.split(':'))]
      os, target_uri, source_uri = nil
    elsif source.ems_ref.starts_with?('/subscriptions')
      os = source.operating_system.product_name
      target_uri, source_uri = nil
      image_reference = { :id => source.ems_ref }
    else
      image_reference = nil
      target_uri, source_uri, os = gather_storage_account_properties
    end

    cloud_options =
    {
      :name       => dest_name,
      :location   => source.location,
      :properties => {
        :licenseType => license_type,
        :availabilitySet => {
          :id => availability_set
        },
        :hardwareProfile => {
          :vmSize => instance_type.name
        },
        :osProfile       => {
          :adminUserName => options[:root_username],
          :adminPassword => root_password,
          :computerName  => dest_hostname
        },
        :storageProfile  => {
          :osDisk        => {
            :createOption => 'FromImage',
            :caching      => 'ReadWrite',
            :osType       => os
          }
        },
        :networkProfile  => {
          :networkInterfaces => [{:id => nic_id}],
        },
        :diagnosticsProfile => {
          :bootDiagnostics => {
            :enabled => enable_boot_diagnostics,
            :storageUri => boot_diagnostics_uri
          }
        }
      }
    }

    if target_uri
      cloud_options[:properties][:storageProfile][:osDisk][:name]  = dest_name + SecureRandom.uuid + '.vhd'
      cloud_options[:properties][:storageProfile][:osDisk][:image] = {:uri => source_uri}
      cloud_options[:properties][:storageProfile][:osDisk][:vhd]   = {:uri => target_uri}
    else
      # Default to a storage account type of "Standard_LRS" for managed images for now.
      cloud_options[:properties][:storageProfile][:osDisk][:managedDisk] = {:storageAccountType => 'Standard_LRS'}
      cloud_options[:properties][:storageProfile][:imageReference] = image_reference
    end

    cloud_options[:properties][:osProfile][:customData] = custom_data unless userdata_payload.nil?
    cloud_options
  end

  def log_clone_options(clone_options)
    dump_obj(clone_options, "#{_log.prefix} Clone Options: ", $log, :info)
    dump_obj(options, "#{_log.prefix} Prov Options:  ", $log, :info, :protected =>
    {:path => workflow_class.encrypted_options_field_regs})
  end

  def region
    source.location
  end

  def start_clone(clone_options)
    source.with_provider_connection do |azure|
      vms = Azure::Armrest::VirtualMachineService.new(azure)
      vm  = vms.create(dest_name, resource_group.name, clone_options)

      {
        :subscription_id   => azure.subscription_id,
        :vm_resource_group => vm.resource_group,
        :type              => vm.type.downcase,
        :vm_name           => vm.name
      }
    end
  end
end

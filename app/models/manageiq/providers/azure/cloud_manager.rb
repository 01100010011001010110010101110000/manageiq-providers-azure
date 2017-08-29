class ManageIQ::Providers::Azure::CloudManager < ManageIQ::Providers::CloudManager
  require_nested :AvailabilityZone
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :Flavor
  require_nested :MetricsCapture
  require_nested :MetricsCollectorWorker
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :Vm
  require_nested :Template
  require_nested :Provision
  require_nested :ProvisionWorkflow
  require_nested :OrchestrationStack
  require_nested :OrchestrationTemplate
  require_nested :OrchestrationServiceOptionConverter

  include ManageIQ::Providers::Azure::ManagerMixin

  alias_attribute :azure_tenant_id, :uid_ems

  has_many :resource_groups, :foreign_key => :ems_id, :dependent => :destroy

  supports :discovery
  supports :provisioning
  supports :regions

  supports :timeline do
    unless insights?
      unsupported_reason_add(:timeline, _('Timeline not supported for this region'))
    end
  end

  before_create :ensure_managers
  before_update :ensure_managers_zone_and_provider_region

  # If the Microsoft.Insights Azure provider is not registered, then neither
  # events nor metrics are supported for that EMS.
  #
  def insights?
    require 'azure-armrest'
    with_provider_connection do |conf|
      rps = ::Azure::Armrest::ResourceProviderService.new(conf)
      rps.get('Microsoft.Insights').registration_state.casecmp('registered').zero?
    end
  end

  def ensure_network_manager
    build_network_manager(:type => 'ManageIQ::Providers::Azure::NetworkManager') unless network_manager
  end

  def self.ems_type
    @ems_type ||= "azure".freeze
  end

  def self.description
    @description ||= "Azure".freeze
  end

  def self.default_blacklisted_event_names
    %w(
      storageAccounts_listKeys_BeginRequest
      storageAccounts_listKeys_EndRequest
    )
  end

  def blacklisted_provider_types
    %r{Microsoft.Classic}
  end

  def self.hostname_required?
    false
  end

  def description
    ManageIQ::Providers::Azure::Regions.find_by_name(provider_region)[:description]
  end

  # Operations

  def vm_start(vm, _options = {})
    vm.start
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_stop(vm, _options = {})
    vm.stop
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_suspend(vm, _options = {})
    vm.suspend
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_destroy(vm, _options = {})
    vm.vm_destroy
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_restart(vm, _options = {})
    # TODO switch to vm.restart
    vm.raw_restart
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_reboot_guest(vm, _options = {})
    vm.reboot_guest
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end
end

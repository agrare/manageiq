class ManageIQ::Providers::EmbeddedAnsible::Inventory::Persister::AutomationManager < ManageIQ::Providers::Awx::Inventory::Persister
  def initialize_inventory_collections
    add_collection(automation, :configuration_scripts)
    add_collection(automation, :configuration_script_payloads) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook)
    end
    add_collection(automation, :configuration_script_sources)
  end
end

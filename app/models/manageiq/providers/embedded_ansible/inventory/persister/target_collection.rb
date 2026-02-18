class ManageIQ::Providers::EmbeddedAnsible::Inventory::Persister::TargetCollection < ManageIQ::Providers::EmbeddedAnsible::Inventory::Persister::AutomationManager
  def targeted?
    true
  end
end

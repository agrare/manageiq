FactoryGirl.define do
  factory :miq_schedule_validation, :class => :MiqSchedule do
    sequence(:name)     { |n| "schedule_#{seq_padded_for_sorting(n)}" }
    description         "test"
    towhat              "MiqReport"
    run_at              {}
    sched_action        {}
  end

  factory :miq_schedule do
    run_at = {:start_time   => "2010-07-08 04:10:00 Z", :interval => {:unit => "daily", :value => "1"}}
    sched_action = {:method => "test"}
    sequence(:name)     { |n| "schedule_#{seq_padded_for_sorting(n)}" }
    description         "test"
    towhat              "MiqReport"
    run_at              run_at
    sched_action        sched_action
  end

  factory :miq_automate_schedule, :class => :MiqSchedule do
    run_at = {:start_time   => "2010-07-08 04:10:00 Z", :interval => {:unit => "daily", :value => "1"}}
    sched_action = {:method => "automation_request"}
    filter = {:uri_parts => {:instance => 'test', :message => 'create'}, :parameters => {'request' => 'test_request'}}
    sequence(:name)     { |n| "automate_schedule_#{seq_padded_for_sorting(n)}" }
    description         "test_automation"
    towhat              "AutomationRequest"
    run_at              run_at
    sched_action        sched_action
    filter              filter
  end
end

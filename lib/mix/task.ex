defmodule Mix.Tasks.RunLookup do
  require Logger

  def run(args) do
    {:ok, _started} = Application.ensure_all_started(:ex_twilio)

    filename = List.first(args)

    if filename == "" or filename == nil do
      Logger.error ~s(Missing filename. Please run "mix run_lookup data/your.csv")
    else
      TwilioListLookup.lookup_and_partition_list(filename)
      :ok
    end
  end
end

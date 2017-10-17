defmodule TwilioListLookup do
  require Logger
  alias NimbleCSV.RFC4180, as: CSV
  alias Osdi.{Repo, PhoneNumber}
  import Ecto.Query

  def lookup_and_partition_list(filename) do
    # [main_output, landline_output, mobile_output, voip_output, unknown_output, not_found_output] =
        # ~w( -processed -landline -mobile -voip -unknown -not-found),
    [main_output, landline_output, other_output] =
      Enum.map(
        ~w(-processed -landline -other),
        fn appendage -> File.open!(create_path(filename, appendage), [:write]) end)

    IO.binwrite(main_output, "Account,Voter File VANID,FirstName,LastName,Fullname,Phone1,Phone2,vAddress,Adress2,City,State,Zip5,Age,Sex,Party,Type\n")
    IO.binwrite(landline_output, "Account,Voter File VANID,FirstName,LastName,Fullname,Phone1,Phone2,vAddress,Adress2,City,State,Zip5,Age,Sex,Party\n")
    IO.binwrite(other_output, "Account,Voter File VANID,FirstName,LastName,Fullname,Phone1,Phone2,vAddress,Adress2,City,State,Zip5,Age,Sex,Party\n")
    # IO.binwrite(mobile_output, "Account,Voter File VANID,FirstName,LastName,Fullname,Phone1,Phone2,vAddress,Adress2,City,State,Zip5,Age,Sex,Party\n")
    # IO.binwrite(voip_output, "Account,Voter File VANID,FirstName,LastName,Fullname,Phone1,Phone2,vAddress,Adress2,City,State,Zip5,Age,Sex,Party\n")
    # IO.binwrite(unknown_output, "Account,Voter File VANID,FirstName,LastName,Fullname,Phone1,Phone2,vAddress,Adress2,City,State,Zip5,Age,Sex,Party\n")
    # IO.binwrite(not_found_output, "Account,Voter File VANID,FirstName,LastName,Fullname,Phone1,Phone2,vAddress,Adress2,City,State,Zip5,Age,Sex,Party\n")

    main_write_fn = fn type, list ->
      csl =
        list
        |> Enum.concat([type])
        |> Enum.join(",")

      IO.binwrite(main_output, "#{csl}\n")
    end

    alt_write_fn = fn type, list ->
      csl = Enum.join list, ","

      output =
        case type do
          "landline" -> landline_output
          "mobile" -> other_output
          "voip" -> other_output
          "unknown" -> other_output
          "not found" -> other_output
        end

      IO.binwrite(output, "#{csl}\n")
    end

    filename
    |> File.stream!()
    |> CSV.parse_stream()
    |> Stream.with_index()
    |> Flow.from_enumerable([max_demand: 20, min_demand: 10])
    |> Flow.map(fn {list, idx} -> {process_line(list, main_write_fn, alt_write_fn), idx} end)
    |> Flow.map(&report/1)
    |> Flow.run()

    Logger.info "Performed #{Counter.get()} twilio lookups"

    Enum.map(
      # [main_output, landline_output, mobile_output, voip_output],
      [main_output, landline_output, other_output],
      fn file -> File.close(file) end)
  end

  defp process_line(list, main_write_fn, alt_write_fn) do
    pn = list |> Enum.at(5) |> get_existing_record()

    type =
      case get_lookup(pn) do
        %{"carrier" => %{"type" => type}} -> type
        %{carrier: %{"type" => type}} -> type
        %{"error" => _error_message} -> "not found"
        %{error: _error_message} -> "not found"
      end

    main_write_fn.(type, list)
    alt_write_fn.(type, list)

    :ok
  end

  defp create_path(basefile, appendage) do
    [base, ending] = String.split(basefile, ".")
    new_sections = [base, appendage, "." <> ending]
    Enum.join(new_sections, "")
  end

  defp report({:ok, idx}) do
    if rem(idx, 10) == 0 do
      Logger.info "Done #{idx}"
    end
  end

  defp get_existing_record(number) do
    case Repo.one(from pn in PhoneNumber, where: pn.number == ^number) do
      nil -> %PhoneNumber{number: number}
      record -> record
    end
  end

  defp get_lookup(pn = %PhoneNumber{twilio_lookup_result: nil, number: number}) do
    lookup =
      case ExTwilio.Lookup.retrieve(pn.number, [type: "carrier"]) do
        {:ok, struct = %{}} -> struct |> Map.from_struct
        {:error, error_message, 404} -> %{error: error_message}
      end

    # Increment counter
    Counter.inc()

    # Store lookup
    changeset = Ecto.Changeset.change(pn, %{twilio_lookup_result: lookup})
    changed =
      if pn.id do
        Repo.update!(changeset)
      else
        case Repo.insert(changeset) do
          {:ok, inserted} -> inserted
          {:error, _error} -> Repo.update((from pn in PhoneNumber, where: pn.number == ^number), set: [twilio_lookup_result: lookup])
        end
      end

    changed.twilio_lookup_result
  end

  defp get_lookup(_pn = %PhoneNumber{twilio_lookup_result: lookup}) do
    lookup
  end
end

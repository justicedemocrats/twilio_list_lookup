defmodule TwilioListLookup do
  require Logger
  alias NimbleCSV.RFC4180, as: CSV
  alias Osdi.{Repo, PhoneNumber}
  import Ecto.Query

  def lookup_and_partition_list(filename) do
    {:ok, file} = File.open(filename, [:read])
    key_line = IO.read(file, :line)
    File.close(file)

    extractor = key_line |> String.trim() |> gen_extractor()

    [main_output, landline_output, other_output] =
      Enum.map(
        ~w(-processed -landline -other),
        fn appendage -> File.open!(create_path(filename, appendage), [:write]) end)

    IO.binwrite(main_output, key_line <> "Type\n")
    IO.binwrite(landline_output, key_line <> "\n")
    IO.binwrite(other_output, key_line <> "\n")

    main_write_fn = fn type, list ->
      csl = list |> Enum.concat([type]) |> Enum.join(",")
      IO.binwrite(main_output, "#{csl}\n")
    end

    alt_write_fn = fn type, list ->
      csl = Enum.join list, ","

      output =
        case type do
          "landline" -> landline_output
          _ -> other_output
        end

      IO.binwrite(output, "#{csl}\n")
    end

    filename
    |> File.stream!()
    |> CSV.parse_stream()
    |> Stream.with_index()
    |> Flow.from_enumerable([max_demand: 20, min_demand: 10])
    |> Flow.map(fn {list, idx} -> {process_line(list, extractor, main_write_fn, alt_write_fn), idx} end)
    |> Flow.map(&report/1)
    |> Flow.run()

    Logger.info "Performed #{Counter.get()} twilio lookups"
    Enum.map([main_output, landline_output, other_output], fn file -> File.close(file) end)
  end

  defp process_line(list, extractor, main_write_fn, alt_write_fn) do
    pn = list |> extractor.() |> get_existing_record()

    type =
      case get_lookup(pn) do
        %{"carrier" => %{"type" => type}} -> type
        %{carrier: %{"type" => type}} -> type
        %{"error" => _error_message} -> "not found"
        %{error: _error_message} -> "not found"
        %{carrier: nil} -> "not found"
        %{"carrier" => nil} -> "not found"
      end

    main_write_fn.(type, list)
    alt_write_fn.(type, list)

    :ok
  end

  defp create_path(basefile, appendage) do
    [ending | reverse_file_parts] = basefile |> String.split(".") |> Enum.reverse()
    new_sections = reverse_file_parts |> Enum.reverse() |> Enum.concat([appendage <> "." <> ending])
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
        case Repo.insert(changeset, [on_conflict: [set: [twilio_lookup_result: lookup]], conflict_target: :number]) do
          {:ok, inserted} -> inserted
          {:error, _error} -> Repo.update((from pn in PhoneNumber, where: pn.number == ^number), set: [twilio_lookup_result: lookup])
        end
      end

    changed.twilio_lookup_result
  end

  defp get_lookup(_pn = %PhoneNumber{twilio_lookup_result: lookup}) do
    lookup
  end

  # VAN
  defp gen_extractor("Account,Voter File VANID,FirstName,LastName,Fullname,Phone1,Phone2,vAddress,Adress2,City,State,Zip,Age,Sex,Party") do
    fn list ->
      case Enum.at(list, 5) do
        "" -> Enum.at(list, 6)
        num -> num
      end
    end
  end

  # BSD Export
  defp gen_extractor("Unique Constituent ID,Prefix,First Name,Middle Name,Last Name,Suffix,Gender,Address 1,Address 2,City,State,Zip,County,Congressional District,State House District,State Senate District,Country,Employer,Occupation,Email,Home Phone,Work Phone,Fax,Mobile Phone,Mobile Phone Opt-In,Join Date,Source,Subsource") do
    fn list ->
      case Enum.at(list, 20) do
        "" ->
          case Enum.at(list, 21) do
            "" -> Enum.at(list, 23) # mobile numb
            work_numb -> work_numb
          end
        home_numb -> home_numb
      end
    end
  end
end

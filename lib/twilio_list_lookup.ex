defmodule TwilioListLookup do
  require Logger
  alias NimbleCSV.RFC4180, as: CSV

  def lookup_and_partition_list(filename) do
    [main_output, landline_output, mobile_output, voip_output, unknown_output, not_found_output] =
      Enum.map(
        ~w( -processed -landline -mobile -voip -unknown -not-found),
        fn appendage -> File.open!(create_path(filename, appendage), [:write]) end)

    IO.binwrite(main_output, "Account,Voter File VANID,FirstName,LastName,Fullname,Phone1,Phone2,vAddress,Adress2,City,State,Zip5,Age,Sex,Party,Type\n")
    IO.binwrite(landline_output, "Account,Voter File VANID,FirstName,LastName,Fullname,Phone1,Phone2,vAddress,Adress2,City,State,Zip5,Age,Sex,Party\n")
    IO.binwrite(mobile_output, "Account,Voter File VANID,FirstName,LastName,Fullname,Phone1,Phone2,vAddress,Adress2,City,State,Zip5,Age,Sex,Party\n")
    IO.binwrite(voip_output, "Account,Voter File VANID,FirstName,LastName,Fullname,Phone1,Phone2,vAddress,Adress2,City,State,Zip5,Age,Sex,Party\n")
    IO.binwrite(unknown_output, "Account,Voter File VANID,FirstName,LastName,Fullname,Phone1,Phone2,vAddress,Adress2,City,State,Zip5,Age,Sex,Party\n")
    IO.binwrite(not_found_output, "Account,Voter File VANID,FirstName,LastName,Fullname,Phone1,Phone2,vAddress,Adress2,City,State,Zip5,Age,Sex,Party\n")

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
          "mobile" -> mobile_output
          "landline" -> landline_output
          "voip" -> voip_output
          "unknown" -> unknown_output
          "not found" -> not_found_output
        end

      IO.binwrite(output, "#{csl}\n")
    end

    filename
    |> File.stream!()
    |> CSV.parse_stream()
    |> Stream.with_index()
    |> ParallelStream.map(fn {list, idx} -> {process_line(list, main_write_fn, alt_write_fn), idx} end, num_workers: 50, worker_work_ratio: 1)
    |> Stream.map(&report/1)
    |> Enum.to_list()

    Enum.map(
      [main_output, landline_output, mobile_output, voip_output],
      fn file -> File.close(file) end)
  end

  defp process_line(list, main_write_fn, alt_write_fn) do
    phone = Enum.at list, 5

    type =
      case ExTwilio.Lookup.retrieve(phone, [type: "carrier"]) do
        {:ok, %{carrier: %{"type" => type}}} -> type
        {:ok, _} -> "unknown"
        {:error, _, 404} -> "not found"
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
end

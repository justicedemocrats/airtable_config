defmodule AirtableConfig do
  defmacro __using__(_opts \\ []) do
    quote do
      def start_link do
        Agent.start_link(
          fn ->
            fetch_all([], 0)
          end,
          name: __MODULE__
        )
      end

      def update() do
        try do
          config = fetch_all([], 0)
          Agent.update(__MODULE__, fn _ -> config end)
          IO.puts("#{table()}: updated at #{inspect(DateTime.utc_now())}")
        rescue
          error ->
            IO.puts(
              "Could not updated config at #{inspect(DateTime.utc_now())}: #{inspect(error)}. Will try again next cycle."
            )
        end
      end

      def get_all do
        Agent.get(__MODULE__, & &1)
      end

      defp fetch_all(prev_records, offset) do
        %{body: body} =
          HTTPotion.get(
            "https://api.airtable.com/v0/#{base}/#{table}",
            headers: [
              Authorization: "Bearer #{key}"
            ],
            query: [offset: offset, view: view()]
          )

        decoded = Poison.decode!(body)

        new_records =
          decoded["records"]
          |> Enum.filter(&filter_record/1)
          |> Enum.map(&process_record/1)
          |> Enum.concat(records)

        if Map.has_key?(decoded, "offset") do
          fetch_all(new_records, decoded["offset"])
        else
          Enum.into(new_records, into_what())
        end
      end
    end
  end
end

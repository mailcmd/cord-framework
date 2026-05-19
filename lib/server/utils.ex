defmodule CORD.Utils do
  alias Hex.API.Key
	def string_keys_to_atom(nil), do: %{}
	def string_keys_to_atom(map) do
    map |> Enum.map(fn
      {k,v} when is_binary(k) -> {String.to_atom(k), v}
      {k,v} -> {k,v}
    end) |> Enum.into(%{})
  end

  def httpc_get(url, headers \\ []) do
    headers =
      headers
      |> Keyword.put(:"user-agent", "Erlang HTTPc")
      |> Enum.map(fn {k, v} -> {to_charlist(k), to_charlist(v)} end)
    
    http_request_opts = [
      autoredirect: true,
      ssl: [
        verify: :verify_peer,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ],
        cacerts: :public_key.cacerts_get()
      ]
    ]

    case :httpc.request(:get, {to_charlist(url), headers}, http_request_opts, []) do
      {:ok, {{_, code, _}, resp_headers, resp_body}} ->
        {:ok, {
          code,
          Enum.map(resp_headers, fn {k, v} -> {to_string(k), to_string(v)} end),
          to_string(resp_body)
        }}
      {:error, error} ->
        {:error, error}
    end
  end  

  def httpc_post(
        url,
        headers \\ [],
        body \\ "",
        content_type \\ "application/x-www-form-urlencoded"
      ) do
    headers =
      headers
      |> Keyword.put(:"user-agent", "Erlang HTTPc")
      |> Enum.map(fn {k, v} -> {to_charlist(k), to_charlist(v)} end)
    
    http_request_opts = [
      autoredirect: true,
      ssl: [
        verify: :verify_peer,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ],
        cacerts: :public_key.cacerts_get()
      ]
    ]

    case :httpc.request(
           :post,
           {to_charlist(url), headers, to_charlist(content_type), to_charlist(body)},
           http_request_opts,
           []
         ) do
      {:ok, {{_, code, _}, resp_headers, resp_body}} ->
        {:ok, {
          code,
          Enum.map(resp_headers, fn {k, v} -> {to_string(k), to_string(v)} end),
          to_string(resp_body)
        }}
      {:error, error} ->
        {:error, error}
    end
  end  
end

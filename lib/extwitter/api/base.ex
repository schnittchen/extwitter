defmodule ExTwitter.API.Base do
  @moduledoc """
  Provides basic and common functionalities for Twitter API.
  """

  @doc """
  Send API request to the twitter server.
  """
  def request(method, path, params \\ []) do
    oauth = ExTwitter.Config.get_tuples |> verify_params
    consumer = {oauth[:consumer_key], oauth[:consumer_secret], :hmac_sha1}
    ExTwitter.OAuth.request(method, request_url(path), params, consumer, oauth[:access_token], oauth[:access_token_secret])
      |> parse_result
  end

  def verify_params([]) do
    raise %ExTwitter.Error{
      message: "OAuth parameters are not set. Use ExTwitter.configure function to set parameters in advance." }
  end

  def verify_params(params), do: params

  defp request_url(path) do
    "https://api.twitter.com/#{path}" |> to_char_list
  end

  defp parse_result(result) do
    {:ok, {_response, header, body}} = result
    verify_response(ExTwitter.JSON.decode!(body), header)
  end

  defp verify_response(body, header) do
    if is_list(body) do
      body
    else
      case Map.get(body, :errors, nil) do
        nil ->
          body
        errors when is_list(errors) ->
          parse_error(List.first(errors), header)
        error ->
          raise(ExTwitter.Error, message: inspect error)
      end
    end
  end

  defp parse_error(error, header) do
    %{:code => code, :message => message} = error
    case code do
      88 ->
        reset_at = fetch_rate_limit_reset(header)
        reset_in = Enum.max([reset_at - Timex.Date.now(:secs), 0])
        raise ExTwitter.RateLimitExceededError,
          code: code, message: message, reset_at: reset_at, reset_in: reset_in
      _  ->
        raise ExTwitter.Error, code: code, message: message
    end
  end

  defp fetch_rate_limit_reset(header) do
    {_, reset_at_in_string} = List.keyfind(header, 'x-rate-limit-reset', 0)
    {reset_at, _} = Integer.parse(to_string(reset_at_in_string))
    reset_at
  end
end

defmodule RnxServerWeb.ViewHelpers do
  @doc """
  Formatea un NaiveDateTime o DateTime a un string legible.
  Ejemplo: "15 de noviembre de 2025"
  """
  def pretty_date(%{year: year, month: month, day: day}) do
    months = %{
      1 => "enero", 2 => "febrero", 3 => "marzo", 4 => "abril",
      5 => "mayo", 6 => "junio", 7 => "julio", 8 => "agosto",
      9 => "septiembre", 10 => "octubre", 11 => "noviembre", 12 => "diciembre"
    }
    "#{day} de #{months[month]} de #{year}"
  end
end
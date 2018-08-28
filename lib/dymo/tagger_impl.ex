defmodule Dymo.TaggerImpl do
  @moduledoc """
  This tagger helps with tagging objects using a backed ecto repo.
  """

  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Ecto.{Schema, Query}
  alias Ecto.Association.NotLoaded
  alias Dymo.{Tag, Tagger}

  @behaviour Tagger

  @repo Dymo.repo()

  @type label :: Tagger.label()
  @type labels :: Tagger.labels()
  @type join_table :: Tagger.join_table()
  @type join_key :: Tagger.join_key()

  @spec set_labels(Schema.t(), label() | labels()) :: Schema.t()
  def set_labels(%{tags: %NotLoaded{}} = struct, lbls),
    do:
      struct
      |> @repo.preload(:tags)
      |> set_labels(lbls)

  def set_labels(%{id: _, tags: _} = struct, lbls),
    do:
      lbls
      |> List.wrap()
      |> maintain_labels_tags(struct)

  @spec add_labels(Schema.t(), label() | labels()) :: Schema.t()
  def add_labels(%{tags: %NotLoaded{}} = struct, lbls),
    do:
      struct
      |> @repo.preload(:tags)
      |> add_labels(lbls)

  def add_labels(%{id: _, tags: _} = struct, lbls),
    do:
      struct
      |> labels()
      |> Kernel.++(List.wrap(lbls))
      |> maintain_labels_tags(struct)

  @spec remove_labels(Schema.t(), label() | labels()) :: Schema.t()
  def remove_labels(%{tags: %NotLoaded{}} = struct, lbls),
    do:
      struct
      |> @repo.preload(:tags)
      |> remove_labels(lbls)

  def remove_labels(%{id: _, tags: _} = struct, lbls),
    do:
      struct
      |> labels()
      |> Kernel.--(List.wrap(lbls))
      |> maintain_labels_tags(struct)

  @spec query_labels(module() | String.t() | Schema.t()) :: Query.t()
  def query_labels(module) when is_atom(module),
    do:
      module
      |> Tagger.join_table()
      |> query_labels()

  def query_labels(join_table) when is_binary(join_table),
    do:
      Tag
      |> join(:inner, [t], tg in ^join_table, t.id == tg.tag_id)
      |> distinct([t, tg], t.label)
      |> select([t, tg], t.label)

  def query_labels(%{id: _, tags: _} = struct),
    do:
      struct
      |> query_labels(Tagger.join_table(struct), Tagger.join_key(struct))

  @spec query_labels(Schema.t(), String.t(), atom) :: Ecto.Query.t()
  def query_labels(%{id: id, tags: _}, join_table, join_key),
    do:
      Tag
      |> join(:inner, [t], tg in ^join_table, t.id == tg.tag_id and field(tg, ^join_key) == ^id)
      |> distinct([t, tg], t.label)
      |> select([t, tg], t.label)

  @spec query_labeled_with(module, label() | labels()) :: Query.t()
  def query_labeled_with(module, lbl_or_lbls),
    do:
      module
      |> query_labeled_with(lbl_or_lbls, Tagger.join_table(module), Tagger.join_key(module))

  @spec query_labeled_with(module, label() | labels(), join_table(), join_key()) :: Query.t()
  def query_labeled_with(module, lbl_or_lbls, join_table, join_key) do
    lbls = List.wrap(lbl_or_lbls)
    lbls_length = length(lbls)

    module
    |> join(:inner, [m], tg in ^join_table, m.id == field(tg, ^join_key))
    |> join(:inner, [m, tg], t in Tag, t.id == tg.tag_id)
    |> where([m, tg, t], t.label in ^lbls)
    |> group_by([m, tg, t], m.id)
    |> having([m, tg, t], count(field(tg, ^join_key)) == ^lbls_length)
    |> order_by([m, tg, t], asc: m.inserted_at)
  end

  @spec labels(Schema.t()) :: labels()
  def labels(%{id: _, tags: _} = struct),
    do:
      struct
      |> @repo.preload(:tags)
      |> Map.get(:tags)
      |> Enum.map(& &1.label)

  @spec maintain_labels_tags(labels(), Schema.t()) :: Schema.t()
  defp maintain_labels_tags(lbls, struct),
    do:
      struct
      |> change
      |> put_assoc(:tags, Tag.find_or_create!(lbls))
      |> @repo.update!()
end
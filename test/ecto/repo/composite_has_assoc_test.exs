defmodule Ecto.Repo.CompositeHasAssocTest do
  use ExUnit.Case, async: true

  import Ecto, only: [put_meta: 2]
  alias Ecto.TestRepo

  defmodule CompositeChild do
    use Ecto.Schema

    schema "composite_children" do
      field :name, :string
      field :org_id, :integer
      field :parent_id, :integer
      timestamps()
    end

    def changeset(struct, params) do
      Ecto.Changeset.cast(struct, params, [:name])
    end
  end

  defmodule CompositeParent do
    use Ecto.Schema

    @primary_key {:id, :integer, []}
    schema "composite_parents" do
      field :org_id, :integer

      has_one :child, CompositeChild,
        references: [org_id: :org_id, id: :parent_id],
        on_replace: :delete

      has_many :children, CompositeChild,
        references: [org_id: :org_id, id: :parent_id],
        on_replace: :delete

      has_one :on_delete_delete_child, CompositeChild,
        references: [org_id: :org_id, id: :parent_id],
        on_delete: :delete_all

      has_one :on_delete_nilify_child, CompositeChild,
        references: [org_id: :org_id, id: :parent_id],
        on_delete: :nilify_all

      has_many :on_delete_delete_children, CompositeChild,
        references: [org_id: :org_id, id: :parent_id],
        on_delete: :delete_all

      has_many :on_delete_nilify_children, CompositeChild,
        references: [org_id: :org_id, id: :parent_id],
        on_delete: :nilify_all
    end
  end

  test "handles has_one composite assoc on insert" do
    sample = %CompositeChild{name: "xyz"}

    changeset =
      %CompositeParent{id: 1, org_id: 10}
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:child, sample)

    schema = TestRepo.insert!(changeset)
    child = schema.child
    assert child.id
    assert child.name == "xyz"
    assert child.org_id == 10
    assert child.parent_id == 1
  end

  test "handles has_many composite assoc on insert" do
    sample = %CompositeChild{name: "abc"}

    changeset =
      %CompositeParent{id: 2, org_id: 20}
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:children, [sample])

    schema = TestRepo.insert!(changeset)
    [child] = schema.children
    assert child.id
    assert child.name == "abc"
    assert child.org_id == 20
    assert child.parent_id == 2
  end

  test "handles has_one composite assoc from struct on insert" do
    schema =
      TestRepo.insert!(%CompositeParent{
        id: 1,
        org_id: 10,
        child: %CompositeChild{name: "xyz"}
      })

    child = schema.child
    assert child.id
    assert child.name == "xyz"
    assert child.org_id == 10
    assert child.parent_id == 1
  end

  test "handles has_many composite assoc from struct on insert" do
    schema =
      TestRepo.insert!(%CompositeParent{
        id: 2,
        org_id: 20,
        children: [%CompositeChild{name: "abc"}]
      })

    [child] = schema.children
    assert child.id
    assert child.name == "abc"
    assert child.org_id == 20
    assert child.parent_id == 2
  end

  test "handles composite assoc on insert preserving parent schema prefix" do
    changeset =
      %CompositeParent{id: 1, org_id: 10}
      |> put_meta(prefix: "prefix")
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:child, %CompositeChild{name: "xyz"})

    schema = TestRepo.insert!(changeset)
    assert schema.child.__meta__.prefix == "prefix"
  end

  test "build/3 sets composite FK fields on has_one" do
    refl = CompositeParent.__schema__(:association, :child)
    parent = %CompositeParent{id: 5, org_id: 42}
    built = Ecto.Association.Has.build(refl, parent, %{})
    assert built.org_id == 42
    assert built.parent_id == 5
  end

  test "build/3 sets composite FK fields on has_many" do
    refl = CompositeParent.__schema__(:association, :children)
    parent = %CompositeParent{id: 7, org_id: 99}
    built = Ecto.Association.Has.build(refl, parent, %{})
    assert built.org_id == 99
    assert built.parent_id == 7
  end

  test "on delete delete_all with composite keys" do
    %CompositeParent{id: 1, org_id: 10}
    |> Ecto.Changeset.change()
    |> TestRepo.delete!()

    assert_received {:delete_all, query}
    assert query.from.source == {"composite_children", CompositeChild}
  end

  test "on delete nilify_all with composite keys" do
    %CompositeParent{id: 1, org_id: 10}
    |> Ecto.Changeset.change()
    |> TestRepo.delete!()

    assert_received {:update_all, query}
    assert query.from.source == {"composite_children", CompositeChild}
  end

  test "on delete composite keys preserves parent schema prefix" do
    %CompositeParent{id: 1, org_id: 10}
    |> put_meta(prefix: "prefix")
    |> Ecto.Changeset.change()
    |> TestRepo.delete!()

    assert_received {:delete_all, %{prefix: "prefix", from: %{source: {"composite_children", _}}}}
    assert_received {:update_all, %{prefix: "prefix", from: %{source: {"composite_children", _}}}}
  end

  test "ignore not loaded composite assoc on insert" do
    schema = %CompositeParent{id: 1, org_id: 10}
    %{child: %Ecto.Association.NotLoaded{}, children: %Ecto.Association.NotLoaded{}} = schema
    loaded = put_in(schema.__meta__.state, :loaded)
    TestRepo.insert!(loaded)
  end
end

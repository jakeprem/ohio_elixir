defmodule OhioElixir.Repo.Migrations.RefactorEventStatus do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :public_at, :utc_datetime_usec
      add :cancelled, :boolean, default: false, null: false
    end

    # Migrate existing data
    execute """
            UPDATE events SET
              public_at = CASE
                WHEN status = 'published' THEN inserted_at
                WHEN status = 'cancelled' THEN inserted_at
                ELSE NULL
              END,
              cancelled = CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END
            """,
            ""

    alter table(:events) do
      remove :status
    end
  end
end

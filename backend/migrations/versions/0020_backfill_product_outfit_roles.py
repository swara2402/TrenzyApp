"""backfill product outfit roles

Revision ID: 0020_backfill_product_outfit_roles
Revises: bd6b596a5943
"""

from alembic import op
import sqlalchemy as sa

revision = "0020_backfill_product_outfit_roles"
down_revision = "bd6b596a5943"
branch_labels = None
depends_on = None


def upgrade() -> None:
    products = sa.table(
        "products",
        sa.column("outfit_role", sa.String()),
        sa.column("article_type", sa.String()),
        sa.column("category", sa.String()),
        sa.column("subcategory", sa.String()),
    )

    value = sa.func.lower(
        sa.func.coalesce(
            products.c.article_type,
            products.c.subcategory,
            products.c.category,
            "",
        )
    )

    role = sa.case(
        (value.op("~")(r"(shoe|sneaker|boot|sandal|footwear|flat|heel)"), "footwear"),
        (value.op("~")(r"(pant|jean|bottom|short|skirt|trouser|legging)"), "bottom"),
        (value.op("~")(r"(jacket|coat|cardigan|blazer|outerwear)"), "outerwear"),
        (value.op("~")(r"(dress|one-piece|gown)"), "dress"),
        (value.op("~")(r"(bag|jewel|accessory|hat|belt|watch)"), "accessory"),
        (value.op("~")(r"(top|shirt|blouse|sweater|hoodie|tee|polo)"), "upper"),
        else_=None,
    )

    op.execute(
        sa.update(products)
        .where(products.c.outfit_role.is_(None))
        .values(outfit_role=role)
    )


def downgrade() -> None:
    # Do not erase manually curated roles on downgrade.
    pass

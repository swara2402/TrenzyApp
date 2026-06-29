
import os

from sqlalchemy import create_engine, text


def main() -> None:
    dsn = os.getenv("POSTGRES_DSN")
    if not dsn:
        raise RuntimeError("POSTGRES_DSN not set in backend/.env")

    engine = create_engine(dsn)

    with engine.begin() as conn:
        # Count current bad rows
        bad_count = conn.execute(
            text("select count(*) from products where image_url like :p"),
            {"p": "%://example.com/%"},
        ).scalar()

        logging.getLogger(__name__).info(
            "Bad placeholder rows (example.com): %s", bad_count
        )


        # Null them out
        conn.execute(
            text(
                "update products set image_url = NULL "
                "where image_url like :p"
            ),
            {"p": "%://example.com/%"},
        )

    logging.getLogger(__name__).info("Done.")



if __name__ == "__main__":
    main()


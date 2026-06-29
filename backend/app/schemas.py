from pydantic import BaseModel


class ReasoningOption(BaseModel):
    title: str | None = None
    price: str | None = None


from app.schemas.common import APIModel


class AskRequest(APIModel):
    question: str


class AskCitation(APIModel):
    source_url: str
    source_title: str = ""
    quote: str = ""


class AskResponse(APIModel):
    answer: str
    citations: list[AskCitation] = []
    refused: bool = False

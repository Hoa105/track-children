"""Import reviewed legal content, never seed placeholder consent in production.

python -m app.seed.legal_documents path/to/reviewed-documents.json
Input: [{"docType":"terms", "version":"1.0", "content":"...",
         "effectiveAt":"2026-10-17T00:00:00Z", "isRequired":true}, ...]
"""
import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, Field, TypeAdapter

from app.core.database import transaction


class Document(BaseModel):
    docType: Literal['terms','privacy','data_policy']
    version: str = Field(min_length=1,max_length=20)
    content: str = Field(min_length=1)
    effectiveAt: datetime
    isRequired: bool = True


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('file',type=Path)
    args=parser.parse_args()
    docs=TypeAdapter(list[Document]).validate_python(json.loads(args.file.read_text(encoding='utf-8')))
    if {d.docType for d in docs}!={'terms','privacy','data_policy'}:
        raise ValueError('Supply terms, privacy and data_policy')
    if any(d.effectiveAt.tzinfo is None for d in docs):
        raise ValueError('effectiveAt must have a timezone')
    with transaction() as db:
        for d in docs:
            db.execute('''INSERT INTO account.legal_documents(doc_type,version,content,is_required,effective_at)
                VALUES (%s,%s,%s,%s,%s) ON CONFLICT(doc_type,version) DO NOTHING''',
                (d.docType,d.version,d.content,d.isRequired,d.effectiveAt))
    print('Legal document versions imported; existing versions were preserved.')


if __name__=='__main__':main()

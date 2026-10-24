"""Deploy reviewed legal JSON, without the removed legal_documents DB table.

python -m app.seed.legal_documents path/to/reviewed-documents.json
Set LEGAL_DOCUMENTS_PATH to the destination file before invoking this command.
Input: [{"docType":"terms", "version":"1.0", "content":"...",
         "effectiveAt":"2026-10-17T00:00:00Z", "isRequired":true}, ...]
"""
import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, Field, TypeAdapter



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
    from app.core.config import settings
    if not settings.legal_documents_path:
        raise ValueError('Set LEGAL_DOCUMENTS_PATH to the deployed JSON file location')
    destination = Path(settings.legal_documents_path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps([d.model_dump(mode='json') for d in docs], ensure_ascii=False, indent=2), encoding='utf-8')
    print('Reviewed legal content exported to configured file; no database changes.')



if __name__=='__main__':main()

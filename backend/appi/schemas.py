from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field, StringConstraints

Name = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]

class Input(BaseModel):
    model_config = ConfigDict(extra='forbid')

class ReservationCreate(Input):
    request_id: UUID
    event_id: str = Field(min_length=1, max_length=100)
    name: Name
    quantity: int = Field(strict=True, ge=1, le=1000)

class Extension(Input):
    request_id: UUID | None = None
    days: int = Field(strict=True, ge=1, le=30)

class Configuration(BaseModel):
    school: str
    year: int
    target_cents: int
    reservation_days: int

class Action(BaseModel):
    id: str
    title: str
    description: str

class Event(BaseModel):
    id: str
    title: str
    capacity: int
    price_cents: int

class Availability(BaseModel):
    event_id: str
    capacity: int
    available: int
    reserved: int
    paid: int

class Reservation(BaseModel):
    id: str
    event_id: str
    name: str
    quantity: int
    price_cents: int
    total_cents: int
    status: Literal['reserved', 'paid', 'cancelled']
    created_at: datetime
    expires_at: datetime
    paid_at: datetime | None
    overdue: bool

class Dashboard(BaseModel):
    target_cents: int
    raised_cents: int
    progress_percent: float

class ErrorDetail(BaseModel):
    code: str
    message: str

class ErrorResponse(BaseModel):
    error: ErrorDetail

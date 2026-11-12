# 0013: force_send_fields and null_fields in request bodies

Status: Accepted (2026-11-12, by the owner through the lead).

## Context

Every generated field is `omitempty`, as Go's are, so a request body
cannot hold an empty value: a PATCH could not send `"attendees": []`
(remove every guest), `"conferenceData": null` (remove a Meet link),
`"useDefault": false` or a reminder override with `"minutes": 0`. Go's
generated types carry `ForceSendFields` and `NullFields` for this, and
`gensupport.MarshalJSON` honors them with reflection. A Calendar user
(scarlet-03, gcp/calendar/apiv3 v0.1.0) was blocked on all four.

## Options

- (a) Go's lists on each model, honored when the body is written.
- (b) Optional scalars `T?` with None meaning "leave out". Xo's
  `omitempty` sends `Some(0)`, `Some(false)` and `Some([])`, so (b)
  covers forced empty values, but not `null`, and it would retype about
  187,000 fields for every reader of a response.
- (c) A raw body override: no types, no help for nested models.

## Decision

(a), with typed lists. Each model a request body can reach (a method's
request schema and every schema it reaches, 29,484 of 61,456) gets

```xo
pub force_send_fields as "~forceSendFields,omitempty": List[EventField] = []
pub null_fields as "~nullFields,omitempty": List[EventField] = []
```

and an enum of its fields, `EventField`, whose variants are Go's field
names. A misspelled field is a compile error, where Go's strings are
silently ignored. Each variant's JSON name is the field's key, then for
a field that is not an Option `=` and its empty value's JSON
(`Attendees as "attendees=[]"`, `Minutes as "minutes=0"`; an int64 sent
as a string is `"0"`).

`gensupport.json_body` writes the body as before when no model in it
sets either list. Otherwise it applies them to the body's JSON value at
every level, nested models and models inside lists included, and drops
both keys:

- A forced field that is absent gets its empty value. A forced Option
  field that is None stays out, as Go never sends a nil pointer.
- A null field is `null`, whatever its value. Go returns an error for a
  null field with a non-empty value; a body Go sends never has both.
- A level that sets either list has its keys sorted, and its values'
  keys, all the way down: Go re-encodes such a level through a
  `map[string]interface{}`.

The four Calendar bodies are tested against what Go's calendar/v3
`Events.Patch` sends for the same ForceSendFields and NullFields
(calendar/apiv3/force_test.xo); gensupport_test.xo covers the rules.

## Consequences

- The lists are ordinary fields, so a model's own `json.encode` shows
  them as `~forceSendFields` and `~nullFields` when the user set them.
  They are `omitempty`, so a decoded response, its re-encoding, and any
  model without them set never show them. A `derive Json` option to
  skip a field is asked of xo (the lead, 2026-11-12); when it lands the
  generator marks both fields skipped and json_body reads them through
  the model, with no change to user code.
- Go's `NullFields` entries for a map key (`"Labels.k"`) are not
  supported: `null_fields` names whole fields.
- Go turns every number under a re-encoded level into a float64; a
  whole number above 2^53 there would differ. Ids above that travel as
  strings in these APIs.
- The generated models grow from 56 MB to 75 MB of source (the enums
  and two fields per request model).

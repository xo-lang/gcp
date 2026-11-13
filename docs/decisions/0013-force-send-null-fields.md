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
pub force_send_fields as "-": List[EventField] = []
pub null_fields as "-": List[EventField] = []
```

and an enum of its fields, `EventField`, whose variants are Go's field
names. A misspelled field is a compile error, where Go's strings are
silently ignored. `as "-"` (xo decision 0622) leaves both lists out of
every derive: a model's JSON never holds them, encoded or decoded.

Each request model also gets `body_marked()` (whether it, or a model in
it, sets either list) and `body_mark(v)`, which writes into v, the
model's JSON, each level's entries: the field's key, then for a field
that is not an Option `=` and its empty value's JSON (`attendees=[]`,
`minutes=0`; an int64 sent as a string is `"0"`), from one generated
match per enum. A generated request passes them to
`gensupport.json_body` only when `body_marked()`: the body is then
written as before when no model in it sets either list. Otherwise
json_body applies the entries at every level, nested models and models
inside lists and maps included:

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

- The lists are skipped fields (`as "-"`), so gcp needs an xo with
  decision 0622 (0.51.0, its first release): an older xo reads `"-"`
  as the JSON key `-`. The first form (2026-11-12, gcp 991353d) put
  them in the model's JSON as `~forceSendFields` and `~nullFields`; its
  decoders paid for the two keys in every model, +13% and +22% of a
  Calendar and a BigQuery program's code with xo 0.49.1.
- Go's `NullFields` entries for a map key (`"Labels.k"`) are not
  supported: `null_fields` names whole fields.
- Go turns every number under a re-encoded level into a float64; a
  whole number above 2^53 there would differ. Ids above that travel as
  strings in these APIs.
- The generated models grow from 56 MB to 107 MB of source (the enums,
  two fields and the two methods per request model). A program's code
  (`__text` plus `_ptext`, darwin/arm64), before and after this form:
  with xo 43f8dfd09, a Calendar events.patch program 1.846 to 2.024 MB
  (+9.6%) and a BigQuery query program 4.067 to 4.373 MB (+7.5%); with
  xo fa4885045 (main, 2026-11-13, whole program, with the Debug table and
  shared returns trims), 1.749 to 1.914 MB (+9.4%) and 3.903 to 4.166 MB
  (+6.7%), an aws control program unchanged at 2.329 MB. The trims cut
  both sides about 5% but leave the cost of this form near the same
  share; the BigQuery part is mostly derived Debug printing the lists
  and decoders giving skipped fields their defaults.

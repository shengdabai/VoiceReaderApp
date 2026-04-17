# Remote Clone API Contract

## Request

`POST /tts`

Headers:

- `Content-Type: application/json`
- `Authorization: Bearer <API_KEY>` (optional)

Body:

```json
{
  "text": "Paragraph text",
  "languageCode": "zh-CN",
  "speed": 1.0,
  "voiceId": "voice_123"
}
```

## Response

- Success: `200` with audio bytes (`audio/mpeg` or `audio/wav`)
- Failure: non-2xx JSON body with message

## Notes

- `speed` follows fixed preset value: 0.5 ~ 3.0
- `languageCode` only accepts: `zh-CN`, `en-US`, `de-DE`
